"""
Экспорт ответов опроса в разные форматы — для исследователей.

Зачем столько форматов?
  - CSV (wide)         : одна строка = один респондент, по колонке на вопрос.
                          Базовый формат для Excel/R/Python/SPSS.
  - CSV (long, tidy)   : одна строка = один ответ. Удобно для tidyverse,
                          pandas.melt, ggplot — разведочный анализ.
  - XLSX               : всё в одной книге, 5 листов (Сводка, Wide, Long,
                          Вопросы, Кодбук). Для тех, кто живёт в Excel.
  - JSON raw           : полный дамп без потерь — multi-choice, вложенные
                          объекты, метаданные респондента. Для разработчиков
                          и для архивации.
  - JSON aggregated    : уже посчитанные агрегаты (как в /analytics),
                          но в виде скачиваемого файла.
  - Codebook CSV       : словарь переменных — без него датасет «слепой».
                          Колонки: имя_переменной, исходный_вопрос, тип,
                          возможные_значения (value labels).
  - SPSS .sav          : бинарный формат SPSS с зашитыми variable_labels
                          и value_labels. После открытия в SPSS/PSPP все
                          вопросы и варианты ответов сразу подписаны
                          по-человечески — не нужно сводить с кодбуком.

Доступ: viewer-роль на опросе (те же правила, что у /analytics).
Параметры: include_incomplete, include_synthetic — применяются ко всем
форматам единообразно.

Авторы wide-CSV для multi-choice: разворачиваем в бинарные колонки
(q{id}__{option_value} = 0/1). Это то, что ждёт SPSS/R, и единственный
способ корректно посчитать частоты выбора каждого варианта. Для long
формата multi-choice раскладывается в отдельные строки — по строке на
выбранный вариант.
"""
from __future__ import annotations

import csv
import io
import json
import re
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Response as FastAPIResponse, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import Answer, CollabRole, Question, Response, Survey, User
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role
from .analytics import survey_analytics  # переиспользуем агрегации


router = APIRouter(prefix="/surveys/{survey_id}/export", tags=["exports"])


# ─────────────────────────── загрузка данных ────────────────────────────

class _Bundle:
    """Всё, что нужно любому экспортёру: метаданные опроса + ответы.

    Грузится одним проходом, чтобы избежать N+1 при сериализации в любой
    из форматов. Внутри уже разрешены варианты вопросов (см. variant_assignments).
    """
    __slots__ = ("survey", "questions", "responses")

    def __init__(self, survey: Survey, questions: list[Question], responses: list[Response]):
        self.survey = survey
        # Сохраняем только «отвечаемые» вопросы — section_header не идёт в датасет,
        # это просто заголовок-разделитель.
        self.questions = [q for q in questions if q.type.value != "section_header"]
        self.responses = responses


async def _load_bundle(
    db: AsyncSession,
    survey_id: int,
    include_incomplete: bool,
    include_synthetic: bool,
) -> _Bundle:
    s_res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey_id)
    )
    survey = s_res.scalar_one()

    q = select(Response).options(selectinload(Response.answers)).where(
        Response.survey_id == survey_id
    )
    if not include_incomplete:
        q = q.where(Response.is_complete.is_(True))
    if not include_synthetic:
        q = q.where(Response.is_synthetic.is_(False))
    r_res = await db.execute(q.order_by(Response.started_at))
    responses = list(r_res.scalars())

    return _Bundle(survey, list(survey.questions), responses)


# ─────────────────────────── общие хелперы ──────────────────────────────

_VAR_BAD = re.compile(r"[^A-Za-z0-9_]")

def _safe_token(s: str, maxlen: int = 40) -> str:
    """Сделать строку безопасной для имени переменной SPSS/R."""
    s = _VAR_BAD.sub("_", str(s))
    return s[:maxlen].strip("_") or "x"


def _var_name(qid: int, option_value: str | None = None) -> str:
    """`q12` для одиночных, `q12__yes` для multi-choice бинарных колонок.

    Имена стабильны: не зависят от title (он меняется без миграций),
    только от question_id и option_value. Это критично для повторяемости
    анализа — старые скрипты не сломаются после переименования вопроса.
    """
    base = f"q{qid}"
    if option_value is None:
        return base
    return f"{base}__{_safe_token(option_value)}"


def _value_of(answer_value: Any) -> Any:
    """Извлечь полезную нагрузку из Answer.value (dict вида {"value": ...})."""
    if isinstance(answer_value, dict):
        return answer_value.get("value", answer_value.get("text"))
    return answer_value


def _option_label(q: Question, value: str) -> str:
    for o in q.options:
        if str(o.value) == str(value):
            return o.label or o.value
    return value


def _iso(dt: datetime | None) -> str | None:
    if dt is None:
        return None
    return dt.astimezone(timezone.utc).isoformat()


def _variant_idx(r: Response, qid: int) -> int:
    """0 — оригинал, -1 — пропущен, 1..N — индекс варианта."""
    v = (r.variant_assignments or {}).get(str(qid))
    if v is None:
        return 0
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


def _response_meta(b: _Bundle, r: Response) -> dict:
    """Колонки-метаданные, общие для wide и long."""
    return {
        "response_id": r.id,
        "started_at": _iso(r.started_at),
        "submitted_at": _iso(r.submitted_at),
        "is_complete": int(r.is_complete),
        "is_synthetic": int(r.is_synthetic),
        # На анонимных опросах user_id не разглашаем даже владельцу — это
        # принципиальное обещание респонденту, а не настройка отображения.
        "user_id": r.user_id if not b.survey.is_anonymous else None,
        "anon_token": r.anon_token,
    }


# ──────────────────────── билдеры таблиц ────────────────────────────────

def _build_wide(b: _Bundle) -> tuple[list[str], list[dict]]:
    """Возвращает (columns, rows) для wide-формата.

    Для каждого вопроса:
      - single_choice/dropdown/scale/text: 1 колонка `q{id}` со значением
      - multiple_choice: N бинарных колонок `q{id}__{opt}` = 0/1, плюс
        колонка `q{id}` со списком выбранных значений (через `;`) — на случай,
        если респондент выбрал что-то «вне» текущих опций (старая опция
        удалена, но ответ остался).
      - У каждого вопроса добавляется `q{id}__variant` (какой вариант
        показывался данному респонденту: 0 = оригинал, -1 = пропуск,
        1..N = вариант). Если опрос вообще без variants, колонка будет
        нулевой — оставляем для единообразия.
    """
    cols: list[str] = [
        "response_id", "started_at", "submitted_at",
        "is_complete", "is_synthetic", "user_id", "anon_token",
    ]
    # Кэш списка колонок для каждого вопроса (нужен при заполнении строк)
    q_cols: dict[int, list[str]] = {}

    for q in b.questions:
        qt = q.type.value
        if qt == "multiple_choice":
            # Раскрываем в бинарные колонки + сводная строковая
            bin_cols = [_var_name(q.id, o.value) for o in q.options]
            q_cols[q.id] = bin_cols + [_var_name(q.id)]
            cols.extend(bin_cols)
            cols.append(_var_name(q.id))
        else:
            q_cols[q.id] = [_var_name(q.id)]
            cols.append(_var_name(q.id))
        cols.append(f"{_var_name(q.id)}__variant")

    rows: list[dict] = []
    q_by_id = {q.id: q for q in b.questions}

    for r in b.responses:
        row = _response_meta(b, r)
        ans_by_qid = {a.question_id: a for a in r.answers}

        for q in b.questions:
            ans = ans_by_qid.get(q.id)
            val = _value_of(ans.value) if ans else None
            qt = q.type.value
            var_name = _var_name(q.id)

            if qt == "multiple_choice":
                picked = set()
                if isinstance(val, list):
                    picked = {str(x) for x in val}
                for o in q.options:
                    row[_var_name(q.id, o.value)] = 1 if str(o.value) in picked else 0
                row[var_name] = ";".join(sorted(picked))
            elif qt == "scale":
                # Храним как число. Пустые ответы — пустая строка, чтобы
                # pandas/SPSS прочитали как NaN/SYSMIS, а не «0».
                try:
                    row[var_name] = float(val) if val not in (None, "") else ""
                except (TypeError, ValueError):
                    row[var_name] = ""
            else:
                row[var_name] = "" if val is None else str(val)

            row[f"{var_name}__variant"] = _variant_idx(r, q.id)

        rows.append(row)

    return cols, rows


def _build_long(b: _Bundle) -> tuple[list[str], list[dict]]:
    """Tidy-формат: одна строка на (response, question, выбранный_вариант_ответа).

    Для multi-choice генерируется по строке на каждый выбранный вариант —
    так и принято в tidyverse, тогда `count(value_text)` даёт верное число
    выборов каждой опции без дополнительного `separate_rows()`.

    Для всех остальных типов — одна строка на (response, question).
    Вопросы без ответа НЕ генерируют строк — отсутствие ответа само по себе
    данные, но в long-формате его записывают как нулевую строку с пустым
    value, что плохо влияет на агрегации. Для подсчёта «не ответил» есть
    wide-формат (там пусто = пропуск).
    """
    cols = [
        "response_id", "started_at", "submitted_at", "is_complete",
        "is_synthetic", "user_id", "anon_token",
        "question_id", "question_type", "question_title",
        "variant_idx", "value_raw", "value_text", "value_numeric",
    ]
    rows: list[dict] = []
    q_by_id = {q.id: q for q in b.questions}

    for r in b.responses:
        meta = _response_meta(b, r)
        for a in r.answers:
            q = q_by_id.get(a.question_id)
            if not q:
                continue
            val = _value_of(a.value)
            qt = q.type.value
            base = {
                **meta,
                "question_id": q.id,
                "question_type": qt,
                "question_title": q.title,
                "variant_idx": _variant_idx(r, q.id),
            }
            if qt == "multiple_choice" and isinstance(val, list):
                for v in val:
                    rows.append({
                        **base,
                        "value_raw": str(v),
                        "value_text": _option_label(q, str(v)),
                        "value_numeric": "",
                    })
                continue

            value_raw = "" if val is None else str(val) if not isinstance(val, list) else json.dumps(val, ensure_ascii=False)
            value_text = ""
            value_num: float | str = ""
            if qt in ("single_choice", "dropdown") and val is not None:
                value_text = _option_label(q, str(val))
            elif qt == "scale":
                try:
                    value_num = float(val)
                except (TypeError, ValueError):
                    value_num = ""
            else:
                value_text = value_raw

            rows.append({
                **base,
                "value_raw": value_raw,
                "value_text": value_text,
                "value_numeric": value_num,
            })

    return cols, rows


def _build_codebook(b: _Bundle) -> tuple[list[str], list[dict]]:
    """Словарь переменных. Без него wide-CSV — просто числа без смысла.

    Для каждой колонки в wide-формате — отдельная строка с:
      - именем переменной (как в файле),
      - id и title исходного вопроса,
      - типом ответа,
      - таблицей возможных значений (для choice-вопросов).
    """
    cols = [
        "variable", "question_id", "question_type", "question_title",
        "required", "scale_min", "scale_max", "value_labels",
    ]
    rows: list[dict] = []

    # Метаданные респондента — тоже описываем
    meta_rows = [
        ("response_id", "id записи (auto-increment)"),
        ("started_at", "ISO-таймстамп начала прохождения (UTC)"),
        ("submitted_at", "ISO-таймстамп завершения (UTC), пусто если не дошёл"),
        ("is_complete", "1 — респондент нажал «Отправить»; 0 — бросил"),
        ("is_synthetic", "1 — сгенерированный AI-респондент (не настоящий)"),
        ("user_id", "id залогиненного пользователя (на анонимных опросах null)"),
        ("anon_token", "одноразовый токен для де-дублирования анонимов"),
    ]
    for name, desc in meta_rows:
        rows.append({
            "variable": name, "question_id": "", "question_type": "metadata",
            "question_title": desc, "required": "", "scale_min": "",
            "scale_max": "", "value_labels": "",
        })

    for q in b.questions:
        cfg = q.config or {}
        scale_min = cfg.get("min", "") if q.type.value == "scale" else ""
        scale_max = cfg.get("max", "") if q.type.value == "scale" else ""
        labels = {str(o.value): o.label for o in q.options}

        if q.type.value == "multiple_choice":
            # бинарные колонки по опциям
            for o in q.options:
                rows.append({
                    "variable": _var_name(q.id, o.value),
                    "question_id": q.id,
                    "question_type": "multiple_choice_dummy",
                    "question_title": f"{q.title} → {o.label or o.value}",
                    "required": int(q.required),
                    "scale_min": 0, "scale_max": 1,
                    "value_labels": '{"0":"не выбрано","1":"выбрано"}',
                })
            # сводная строковая
            rows.append({
                "variable": _var_name(q.id),
                "question_id": q.id,
                "question_type": "multiple_choice_joined",
                "question_title": q.title,
                "required": int(q.required),
                "scale_min": "", "scale_max": "",
                "value_labels": json.dumps(labels, ensure_ascii=False),
            })
        else:
            rows.append({
                "variable": _var_name(q.id),
                "question_id": q.id,
                "question_type": q.type.value,
                "question_title": q.title,
                "required": int(q.required),
                "scale_min": scale_min, "scale_max": scale_max,
                "value_labels": json.dumps(labels, ensure_ascii=False) if labels else "",
            })

        # variant-колонка
        rows.append({
            "variable": f"{_var_name(q.id)}__variant",
            "question_id": q.id,
            "question_type": "variant_index",
            "question_title": f"Какой вариант вопроса увидел респондент: {q.title}",
            "required": "", "scale_min": -1, "scale_max": "",
            "value_labels": '{"0":"оригинал","-1":"пропущен","1..N":"индекс варианта (см. config.variants)"}',
        })

    return cols, rows


# ─────────────────────── сериализаторы файлов ───────────────────────────

def _csv_bytes(columns: list[str], rows: list[dict]) -> bytes:
    """CSV с BOM — чтобы Excel под Windows не ломал кириллицу."""
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=columns, extrasaction="ignore", lineterminator="\n")
    w.writeheader()
    for row in rows:
        w.writerow(row)
    return ("﻿" + buf.getvalue()).encode("utf-8")


def _xlsx_bytes(b: _Bundle, agg: dict) -> bytes:
    from openpyxl import Workbook
    from openpyxl.styles import Font, PatternFill, Alignment

    wb = Workbook()

    # ── Лист 1: Сводка ──
    s = wb.active
    s.title = "Сводка"
    header_font = Font(bold=True, size=14, color="FFFFFF")
    header_fill = PatternFill("solid", fgColor="0F2D69")  # HSE primary
    s["A1"] = "Экспорт ответов"
    s["A1"].font = header_font
    s["A1"].fill = header_fill
    s.merge_cells("A1:B1")
    summary = [
        ("Опрос", b.survey.title),
        ("Slug", b.survey.slug),
        ("ID", b.survey.id),
        ("Статус", b.survey.status.value),
        ("Анонимный", "да" if b.survey.is_anonymous else "нет"),
        ("Всего ответов", agg.get("total_responses", 0)),
        ("Завершено", agg.get("completed_responses", 0)),
        ("Экспортировано", datetime.now(timezone.utc).isoformat(timespec="seconds")),
    ]
    for i, (k, v) in enumerate(summary, start=3):
        s.cell(row=i, column=1, value=k).font = Font(bold=True)
        s.cell(row=i, column=2, value=str(v))
    s.column_dimensions["A"].width = 22
    s.column_dimensions["B"].width = 60

    def _dump(ws_name: str, columns: list[str], rows: list[dict]):
        ws = wb.create_sheet(ws_name)
        for c, name in enumerate(columns, start=1):
            cell = ws.cell(row=1, column=c, value=name)
            cell.font = Font(bold=True)
            cell.fill = PatternFill("solid", fgColor="E6E6E6")
        for r_idx, row in enumerate(rows, start=2):
            for c, name in enumerate(columns, start=1):
                ws.cell(row=r_idx, column=c, value=row.get(name))
        ws.freeze_panes = "A2"

    wide_cols, wide_rows = _build_wide(b)
    _dump("Ответы (wide)", wide_cols, wide_rows)
    long_cols, long_rows = _build_long(b)
    _dump("Ответы (long)", long_cols, long_rows)
    cb_cols, cb_rows = _build_codebook(b)
    _dump("Кодбук", cb_cols, cb_rows)

    # Вопросы как отдельный лист
    qrows = [{
        "question_id": q.id, "position": q.position, "type": q.type.value,
        "title": q.title, "required": int(q.required),
        "options_count": len(q.options),
        "has_variants": int(bool((q.config or {}).get("variants"))),
    } for q in b.questions]
    _dump("Вопросы", ["question_id", "position", "type", "title", "required",
                       "options_count", "has_variants"], qrows)

    # Агрегации (для тех, кто хочет посмотреть распределения сразу в Excel)
    agg_rows = []
    for q_stat in agg.get("questions", []):
        agg_rows.append({
            "question_id": q_stat["question_id"],
            "type": q_stat["type"],
            "title": q_stat["title"],
            "total_answers": q_stat["total_answers"],
            "distribution_json": json.dumps(q_stat["distribution"], ensure_ascii=False),
            "by_variant_json": json.dumps(q_stat.get("by_variant", {}), ensure_ascii=False),
        })
    _dump("Агрегации", ["question_id", "type", "title", "total_answers",
                         "distribution_json", "by_variant_json"], agg_rows)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _sav_bytes(b: _Bundle) -> bytes:
    """SPSS .sav через pyreadstat. Подгружаем по требованию.

    Если pyreadstat не установлен (например, в dev-окружении без C-toolchain),
    отдаём 503 с понятным сообщением — а не падаем при импорте модуля.

    История падений (важно для будущих правок!):
      1. pyreadstat капризен к dtype: object-колонка со смесью float и None
         (например, scale-вопрос с пустыми ответами) → write_sav бросает
         внутреннюю ошибку и Starlette показывает голый 500. Лечится
         принудительной типизацией каждой колонки через _to_num/_to_str
         ДО передачи в write_sav.
      2. user_id у анонимного опроса — это столбец из одних None. Object-
         dtype с одними None pyreadstat не умеет — нужно явно сделать его
         numeric (станет столбцом из NaN, в SAV запишется как SYSMIS).
      3. variable_value_labels требует, чтобы тип ключа в словаре совпадал
         с dtype колонки в DataFrame. Если для __variant-колонки прислать
         {0: ...} (int), а dtype вдруг object — pyreadstat падает с
         «inconsistent value labels». Лечится финальной сверкой
         `cleaned_value_labels` ниже.
      4. Любой сбой записи раньше уходил как голый 500 без сообщения.
         Теперь оборачиваем write_sav в try/except и отдаём 500 с
         текстом исключения — следующий пользователь хотя бы поймёт,
         какая колонка сломалась.
    """
    try:
        import pandas as pd
        import pyreadstat
    except ImportError as e:  # pragma: no cover
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            f"SPSS export недоступен: не установлен pyreadstat ({e}). "
            "Используйте CSV/XLSX или установите pyreadstat на сервере.",
        )

    cols, rows = _build_wide(b)
    df = pd.DataFrame(rows, columns=cols) if rows else pd.DataFrame(columns=cols)

    variable_labels: dict[str, str] = {
        "response_id":  "ID записи",
        "started_at":   "Начало прохождения (UTC)",
        "submitted_at": "Завершение (UTC)",
        "is_complete":  "Завершён",
        "is_synthetic": "Сгенерирован AI",
        "user_id":      "ID пользователя (если не анонимный)",
        "anon_token":   "Анонимный токен",
    }
    value_labels: dict[str, dict[Any, str]] = {}

    # ── Хелперы типизации ────────────────────────────────────────────
    # pd.to_numeric с errors='coerce' превращает '' и нечисловые значения
    # в NaN — а NaN pyreadstat правильно мапит в SPSS SYSMIS.
    def _to_num(col: str) -> None:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors="coerce")

    # Для строковых колонок None и NaN превращаем в "", иначе в SAV
    # запишется буквальная строка "None" / "nan", что неприятно
    # выглядит в SPSS.
    def _to_str(col: str) -> None:
        if col in df.columns:
            df[col] = df[col].apply(
                lambda v: "" if v is None or (isinstance(v, float) and pd.isna(v)) else str(v)
            )

    # ── Метаданные ──
    for c in ("response_id", "is_complete", "is_synthetic", "user_id"):
        _to_num(c)
    for c in ("started_at", "submitted_at", "anon_token"):
        _to_str(c)

    # ── Колонки вопросов ──
    for q in b.questions:
        title = (q.title or f"q{q.id}")[:255]
        qt = q.type.value
        vname = _var_name(q.id)
        vvariant = f"{vname}__variant"

        if qt == "multiple_choice":
            for o in q.options:
                bn = _var_name(q.id, o.value)
                _to_num(bn)
                variable_labels[bn] = f"{title} → {(o.label or o.value)[:200]}"[:255]
                value_labels[bn] = {0: "не выбрано", 1: "выбрано"}
            # Joined-колонка из ;-разделённых значений — это строка без
            # value-labels (несколько значений сразу метками не описать).
            _to_str(vname)
            variable_labels[vname] = title
        elif qt == "scale":
            _to_num(vname)
            variable_labels[vname] = title
        else:
            # single_choice / dropdown / short_text / long_text — строки.
            _to_str(vname)
            variable_labels[vname] = title
            if q.options and qt in ("single_choice", "dropdown"):
                value_labels[vname] = {
                    str(o.value): (o.label or str(o.value))[:120]
                    for o in q.options
                }

        # variant-колонка всегда числовая (см. _variant_idx)
        _to_num(vvariant)
        variable_labels[vvariant] = f"Вариант, показанный респонденту: {title}"[:255]
        value_labels[vvariant] = {
            0: "оригинал", -1: "пропущен",
            1: "вариант 1", 2: "вариант 2", 3: "вариант 3",
        }

    # ── Финальная сверка value_labels с реальными dtype колонок ──
    # pyreadstat требует, чтобы ключи value_labels были того же типа,
    # что и значения в колонке. После _to_num/_to_str dtype определён,
    # можно нормализовать ключи.
    cleaned_value_labels: dict[str, dict] = {}
    for col, labels in value_labels.items():
        if col not in df.columns:
            continue
        try:
            if pd.api.types.is_numeric_dtype(df[col]):
                cleaned_value_labels[col] = {
                    float(k): str(v)[:120] for k, v in labels.items()
                }
            else:
                cleaned_value_labels[col] = {
                    str(k): str(v)[:120] for k, v in labels.items()
                }
        except (TypeError, ValueError):
            # Лучше отдать файл без меток для одной колонки, чем 500
            # из-за неконвертируемого ключа.
            continue

    import tempfile, os
    with tempfile.NamedTemporaryFile(suffix=".sav", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        try:
            pyreadstat.write_sav(
                df, tmp_path,
                column_labels=[variable_labels.get(c, c) for c in df.columns],
                variable_value_labels=cleaned_value_labels,
            )
        except Exception as e:
            # Конвертируем внутреннее исключение pyreadstat в осмысленный
            # HTTP-ответ: пользователь хотя бы поймёт, что именно пошло
            # не так (раньше получал голый 500 без тела).
            raise HTTPException(
                status.HTTP_500_INTERNAL_SERVER_ERROR,
                f"Не удалось сформировать SPSS-файл: {type(e).__name__}: {e}",
            )
        with open(tmp_path, "rb") as f:
            return f.read()
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


# ─────────────────────────── endpoints ──────────────────────────────────

def _attach(filename: str, media_type: str, body: bytes) -> FastAPIResponse:
    return FastAPIResponse(
        content=body,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            # Открываем CORS-заголовок для имени файла — иначе фронт не
            # сможет прочитать его из ответа и придётся хардкодить.
            "Access-Control-Expose-Headers": "Content-Disposition",
        },
    )


async def _authorized_bundle(
    survey_id: int, db: AsyncSession, user: User,
    include_incomplete: bool, include_synthetic: bool,
) -> _Bundle:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.viewer)
    return await _load_bundle(db, survey_id, include_incomplete, include_synthetic)


@router.get("/responses.csv")
async def export_csv(
    survey_id: int,
    layout: str = Query("wide", pattern="^(wide|long)$"),
    include_incomplete: bool = True,
    include_synthetic: bool = True,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    b = await _authorized_bundle(survey_id, db, user, include_incomplete, include_synthetic)
    cols, rows = _build_wide(b) if layout == "wide" else _build_long(b)
    fn = f"{b.survey.slug}_responses_{layout}.csv"
    return _attach(fn, "text/csv; charset=utf-8", _csv_bytes(cols, rows))


@router.get("/codebook.csv")
async def export_codebook(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    b = await _authorized_bundle(survey_id, db, user, True, True)
    cols, rows = _build_codebook(b)
    return _attach(f"{b.survey.slug}_codebook.csv", "text/csv; charset=utf-8",
                   _csv_bytes(cols, rows))


@router.get("/responses.json")
async def export_json(
    survey_id: int,
    include_incomplete: bool = True,
    include_synthetic: bool = True,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    b = await _authorized_bundle(survey_id, db, user, include_incomplete, include_synthetic)
    payload = {
        "survey": {
            "id": b.survey.id, "title": b.survey.title, "slug": b.survey.slug,
            "status": b.survey.status.value, "is_anonymous": b.survey.is_anonymous,
            "created_at": _iso(b.survey.created_at),
            "published_at": _iso(b.survey.published_at),
        },
        "questions": [
            {
                "id": q.id, "type": q.type.value, "title": q.title,
                "position": q.position, "required": q.required,
                "config": q.config, "display_condition": q.display_condition,
                "options": [{"value": o.value, "label": o.label, "position": o.position}
                            for o in q.options],
            } for q in b.questions
        ],
        "responses": [
            {
                **_response_meta(b, r),
                "variant_assignments": r.variant_assignments or {},
                "synthetic_profile": r.synthetic_profile if r.is_synthetic else None,
                "answers": [
                    {"question_id": a.question_id, "value": a.value}
                    for a in r.answers
                ],
            } for r in b.responses
        ],
        "exported_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    return _attach(f"{b.survey.slug}_raw.json", "application/json", body)


@router.get("/analytics.json")
async def export_analytics_json(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Переиспользуем существующую функцию агрегации
    agg = await survey_analytics(survey_id=survey_id, user=user, db=db)
    payload = agg.model_dump() if hasattr(agg, "model_dump") else agg.dict()
    body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
    fn = f"survey_{survey_id}_analytics.json"
    return _attach(fn, "application/json", body)


@router.get("/responses.xlsx")
async def export_xlsx(
    survey_id: int,
    include_incomplete: bool = True,
    include_synthetic: bool = True,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    b = await _authorized_bundle(survey_id, db, user, include_incomplete, include_synthetic)
    agg = await survey_analytics(survey_id=survey_id, user=user, db=db)
    agg_dict = agg.model_dump() if hasattr(agg, "model_dump") else agg.dict()
    body = _xlsx_bytes(b, agg_dict)
    return _attach(f"{b.survey.slug}_responses.xlsx",
                   "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                   body)


@router.get("/responses.sav")
async def export_sav(
    survey_id: int,
    include_incomplete: bool = True,
    include_synthetic: bool = True,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    b = await _authorized_bundle(survey_id, db, user, include_incomplete, include_synthetic)
    body = _sav_bytes(b)
    return _attach(f"{b.survey.slug}_responses.sav", "application/x-spss-sav", body)
