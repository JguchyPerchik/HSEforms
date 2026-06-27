"""Best-effort importers for Google Forms and Yandex Forms.

Обе платформы рендерят свои формы как SPA, но **публично** встраивают
в HTML JSON со структурой формы (Google — переменная FB_PUBLIC_LOAD_DATA_
в inline-скрипте, Яндекс — JSON в `<script id="...">`). Мы тянем HTML,
вытаскиваем этот JSON и переводим каждый распознанный вопрос в наш
QuestionType. Всё, что не поддерживается (сетки, дата, время, загрузка
файлов, изображения, видео и т.д.) — молча пропускается; пользователь
получает обратно ровно те вопросы, которые мы умеем добросовестно
воспроизвести.

Подход «best-effort»: парсеры не гарантируют 100% обратной совместимости
со всеми редакциями форматов Google/Яндекса. При смене формата платформы-
донора достаточно подкрутить regex/walker, не трогая публичный API.
"""
from __future__ import annotations

import json
import re
from typing import Any
from urllib.parse import urlparse

import httpx

from ..models.question import QuestionType


class FormImportError(Exception):
    """Поднимается, когда URL нельзя загрузить или форму не получилось распарсить."""


# ---------------------------------------------------------------------------
# Provider detection
# ---------------------------------------------------------------------------

def detect_provider(url: str) -> str:
    host = (urlparse(url).hostname or "").lower()
    if "docs.google.com" in host or "forms.gle" in host or "goo.gl" in host:
        return "google"
    if "forms.yandex" in host:
        return "yandex"
    raise FormImportError("Поддерживаются только ссылки Google Forms и Яндекс Форм")


async def _fetch_html(url: str) -> str:
    async with httpx.AsyncClient(follow_redirects=True, timeout=20.0) as cl:
        try:
            r = await cl.get(
                url,
                headers={
                    # Подставляем браузерный UA — без него Google отдаёт
                    # упрощённую (бот-friendly) версию страницы без
                    # FB_PUBLIC_LOAD_DATA_ блока.
                    "User-Agent": (
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/124.0 Safari/537.36"
                    ),
                    "Accept-Language": "ru-RU,ru;q=0.9,en;q=0.8",
                },
            )
        except httpx.HTTPError as e:
            raise FormImportError(f"Не удалось загрузить страницу: {e}") from e
    if r.status_code >= 400:
        raise FormImportError(
            f"Страница вернула HTTP {r.status_code}. Убедитесь, что форма открытая."
        )
    return r.text


# ---------------------------------------------------------------------------
# Google Forms
# ---------------------------------------------------------------------------
# Google встраивает структуру формы как JS-массив:
#   var FB_PUBLIC_LOAD_DATA_ = [ ... ];
# Хватаем жадно до закрывающего `;</script>`.

_GOOGLE_BLOB_RX = re.compile(
    r"FB_PUBLIC_LOAD_DATA_\s*=\s*(\[.*?\])\s*;\s*</script>",
    re.DOTALL,
)

# Численные коды типов внутри FB_PUBLIC_LOAD_DATA_.
#   0 short answer · 1 paragraph · 2 radio · 3 dropdown · 4 checkbox
#   5 linear scale · 6 title block · 7 grid · 8 section/page break
#   9 date · 10 time · 11 image · 12 video · 13 file upload
# Мы поддерживаем только то, для чего у нас есть QuestionType:
_GOOGLE_TYPE_MAP: dict[int, QuestionType] = {
    0: QuestionType.short_text,
    1: QuestionType.long_text,
    2: QuestionType.single_choice,
    3: QuestionType.dropdown,
    4: QuestionType.multiple_choice,
    5: QuestionType.scale,
}


def _safe(node: Any, *path: Any, default: Any = None) -> Any:
    """Безопасный обход вложенной структуры list/dict: если на любом шаге
    индекс/ключ отсутствует — возвращает default. Без этого парсинг
    Google'овского массива превращается в каскад try/except."""
    cur = node
    for k in path:
        try:
            cur = cur[k]
        except (IndexError, KeyError, TypeError):
            return default
    return cur


def _g_options(item: list) -> list[dict[str, Any]]:
    raw = _safe(item, 4, 0, 1, default=[]) or []
    out: list[dict[str, Any]] = []
    pos = 0
    for opt in raw:
        if not isinstance(opt, list) or not opt:
            continue
        label = str(opt[0] or "").strip()
        if not label:
            continue
        out.append({"label": label, "value": label, "position": pos})
        pos += 1
    return out


def _g_required(item: list) -> bool:
    val = _safe(item, 4, 0, 2, default=0)
    try:
        return bool(int(val))
    except (TypeError, ValueError):
        return False


def _g_scale_config(item: list) -> dict[str, Any]:
    labels = _g_options(item)
    bounds = _safe(item, 4, 0, 3, default=[]) or []
    cfg: dict[str, Any] = {
        "show_ticks": True,
        "show_value": True,
        "show_bounds": True,
    }
    if labels:
        try:
            nums = [int(o["label"]) for o in labels]
            cfg["min"] = min(nums)
            cfg["max"] = max(nums)
        except (ValueError, KeyError):
            cfg["min"] = 1
            cfg["max"] = len(labels)
    else:
        cfg["min"] = 1
        cfg["max"] = 5
    if isinstance(bounds, list) and len(bounds) >= 2:
        if bounds[0]:
            cfg["min_label"] = str(bounds[0])
        if bounds[1]:
            cfg["max_label"] = str(bounds[1])
    return cfg


def parse_google_form(
    html: str,
) -> tuple[str | None, str | None, list[dict[str, Any]], int]:
    m = _GOOGLE_BLOB_RX.search(html)
    if not m:
        raise FormImportError(
            "Не нашёл блок FB_PUBLIC_LOAD_DATA_ — форма закрыта или ссылка некорректна."
        )
    try:
        data = json.loads(m.group(1))
    except json.JSONDecodeError as e:
        raise FormImportError(f"Не удалось разобрать JSON Google Form: {e}") from e

    title = _safe(data, 3) or _safe(data, 1, 8)
    description = _safe(data, 1, 0)
    items = _safe(data, 1, 1, default=[]) or []

    questions: list[dict[str, Any]] = []
    pending_break = False
    skipped = 0

    for item in items:
        if not isinstance(item, list) or len(item) < 4:
            continue
        gtype = item[3]
        i_title = str(item[1] or "").strip() if len(item) > 1 else ""
        i_desc = (
            str(item[2]).strip() if len(item) > 2 and isinstance(item[2], str) and item[2].strip()
            else None
        )

        # Section / page break — превращаем в section_header с
        # page_break_before=True. Если у break'a нет ни заголовка, ни
        # описания — он сам по себе бесполезен как заголовок, но мы
        # помним, что СЛЕДУЮЩИЙ вопрос должен начаться с новой страницы.
        if gtype == 8:
            if i_title or i_desc:
                questions.append({
                    "type": QuestionType.section_header,
                    "title": i_title,
                    "description": i_desc,
                    "page_break_before": True,
                    "required": False,
                    "config": {},
                    "options": [],
                })
                pending_break = False
            else:
                pending_break = True
            continue

        # Title / section header без разрыва страницы.
        if gtype == 6:
            questions.append({
                "type": QuestionType.section_header,
                "title": i_title,
                "description": i_desc,
                "page_break_before": pending_break,
                "required": False,
                "config": {},
                "options": [],
            })
            pending_break = False
            continue

        qtype = _GOOGLE_TYPE_MAP.get(gtype)
        if qtype is None:
            # Неподдерживаемый тип (сетка, дата, время, file upload, image,
            # video) — молча пропускаем, но считаем в skipped, чтобы
            # вернуть пользователю «импортировано X, пропущено Y».
            skipped += 1
            continue

        cfg: dict[str, Any] = {}
        options: list[dict[str, Any]] = []
        if qtype is QuestionType.scale:
            cfg = _g_scale_config(item)
        elif qtype in (
            QuestionType.single_choice,
            QuestionType.multiple_choice,
            QuestionType.dropdown,
        ):
            options = _g_options(item)
            if not options:
                # Choice без опций у нас не валиден — пропускаем.
                skipped += 1
                continue

        questions.append({
            "type": qtype,
            "title": i_title,
            "description": i_desc,
            "page_break_before": pending_break,
            "required": _g_required(item),
            "config": cfg,
            "options": options,
        })
        pending_break = False

    return (
        (str(title) if title else None),
        (str(description) if description else None),
        questions,
        skipped,
    )


# ---------------------------------------------------------------------------
# Yandex Forms
# ---------------------------------------------------------------------------
# Яндекс Формы — SPA, начальное состояние встроено как JSON в одном из
# нескольких возможных <script>-тегов. Перебираем известные обёртки
# и обходим каждый blob в поисках объектов, похожих на вопросы
# (имеют answer_type / type / kind / question_type).

_YA_JSON_PATTERNS = [
    re.compile(
        r'<script[^>]+id="initialState"[^>]*>(.*?)</script>',
        re.DOTALL,
    ),
    re.compile(
        r'<script[^>]+id="__NEXT_DATA__"[^>]*>(.*?)</script>',
        re.DOTALL,
    ),
    re.compile(
        r'<script[^>]+id="initial-data"[^>]*>(.*?)</script>',
        re.DOTALL,
    ),
    re.compile(
        r'window\.__INITIAL_STATE__\s*=\s*(\{.*?\})\s*;',
        re.DOTALL,
    ),
    re.compile(
        r'window\.__PRELOADED_STATE__\s*=\s*(\{.*?\})\s*;',
        re.DOTALL,
    ),
]

_YA_TYPE_MAP: dict[str, QuestionType | None] = {
    "answer_short_text": QuestionType.short_text,
    "answer_long_text": QuestionType.long_text,
    "answer_choices": QuestionType.single_choice,
    "answer_choices_one": QuestionType.single_choice,
    "answer_radio": QuestionType.single_choice,
    "answer_choices_multiple": QuestionType.multiple_choice,
    "answer_choices_many": QuestionType.multiple_choice,
    "answer_checkbox": QuestionType.multiple_choice,
    "answer_choices_dropdown": QuestionType.dropdown,
    "answer_dropdown": QuestionType.dropdown,
    "answer_select": QuestionType.dropdown,
    "answer_scale": QuestionType.scale,
    "answer_rating": QuestionType.scale,
    "section": QuestionType.section_header,
    "section_header": QuestionType.section_header,
    "page_break": None,  # сигнал «следующий вопрос с новой страницы»
}

_LIKELY_TYPE_KEYS = ("answer_type", "type", "question_type", "kind", "control_type")


def _ya_extract_blobs(html: str) -> list[Any]:
    blobs: list[Any] = []
    for rx in _YA_JSON_PATTERNS:
        for m in rx.finditer(html):
            txt = (m.group(1) or "").strip()
            if not txt:
                continue
            try:
                blobs.append(json.loads(txt))
            except json.JSONDecodeError:
                # Скрипт может содержать не-JSON код (Яндекс иногда
                # минифицирует JSX в тех же тегах) — игнорируем.
                continue
    return blobs


def _ya_node_type(node: dict) -> str | None:
    for k in _LIKELY_TYPE_KEYS:
        v = node.get(k)
        if isinstance(v, str):
            return v
    return None


def _ya_walk(node: Any, hits: list[dict]) -> None:
    """Рекурсивный обход — собираем все dict'ы, у которых поле типа
    начинается на 'answer_' или совпадает с section/page_break."""
    if isinstance(node, dict):
        t = _ya_node_type(node)
        if isinstance(t, str) and (
            t.startswith("answer_") or t in {"section", "section_header", "page_break"}
        ):
            hits.append(node)
        for v in node.values():
            _ya_walk(v, hits)
    elif isinstance(node, list):
        for v in node:
            _ya_walk(v, hits)


def _ya_options(node: dict) -> list[dict[str, Any]]:
    raw = (
        node.get("options")
        or node.get("choices")
        or node.get("answer_choices")
        or node.get("items")
        or node.get("variants")
        or []
    )
    if not isinstance(raw, list):
        return []
    out: list[dict[str, Any]] = []
    pos = 0
    for o in raw:
        if isinstance(o, dict):
            label = (
                o.get("label")
                or o.get("text")
                or o.get("title")
                or o.get("name")
                or o.get("value")
                or ""
            )
        else:
            label = o
        label = str(label or "").strip()
        if not label:
            continue
        out.append({"label": label, "value": label, "position": pos})
        pos += 1
    return out


def _ya_required(node: dict) -> bool:
    for k in ("required", "is_required", "answer_required", "mandatory"):
        if k in node:
            return bool(node[k])
    return False


def _ya_title(node: dict) -> str:
    for k in ("title", "label", "question", "name", "text"):
        v = node.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def _ya_description(node: dict) -> str | None:
    for k in ("description", "hint", "subtitle", "help"):
        v = node.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return None


def _ya_scale_config(node: dict) -> dict[str, Any]:
    mn = (
        node.get("min")
        or node.get("min_value")
        or node.get("scale_min")
        or node.get("from")
        or 1
    )
    mx = (
        node.get("max")
        or node.get("max_value")
        or node.get("scale_max")
        or node.get("to")
        or 5
    )
    try:
        mni, mxi = int(mn), int(mx)
    except (TypeError, ValueError):
        mni, mxi = 1, 5
    cfg: dict[str, Any] = {
        "min": mni,
        "max": mxi,
        "show_ticks": True,
        "show_value": True,
        "show_bounds": True,
    }
    low = node.get("min_label") or node.get("low_label") or node.get("left_label")
    high = node.get("max_label") or node.get("high_label") or node.get("right_label")
    if isinstance(low, str) and low.strip():
        cfg["min_label"] = low.strip()
    if isinstance(high, str) and high.strip():
        cfg["max_label"] = high.strip()
    return cfg


def _ya_find_title(blobs: list[Any]) -> tuple[str | None, str | None]:
    """Найти заголовок и описание самой формы (не вопросов).
    Эвристика: ищем dict, который выглядит как контейнер формы
    (наличие questions/items/form/survey-полей) — у такого читаем
    title и description."""
    title: str | None = None
    description: str | None = None

    def visit(node: Any) -> None:
        nonlocal title, description
        if title and description:
            return
        if isinstance(node, dict):
            looks_like_form = (
                "questions" in node or "items" in node or "form" in node or "survey" in node
            )
            if not title:
                for k in ("form_title", "survey_title", "name"):
                    v = node.get(k)
                    if isinstance(v, str) and v.strip():
                        title = v.strip()
                        break
                if not title and looks_like_form:
                    v = node.get("title")
                    if isinstance(v, str) and v.strip():
                        title = v.strip()
            if not description and looks_like_form:
                v = node.get("description")
                if isinstance(v, str) and v.strip():
                    description = v.strip()
            for v in node.values():
                visit(v)
        elif isinstance(node, list):
            for v in node:
                visit(v)

    for b in blobs:
        visit(b)
    return title, description


def parse_yandex_form(
    html: str,
) -> tuple[str | None, str | None, list[dict[str, Any]], int]:
    blobs = _ya_extract_blobs(html)
    if not blobs:
        raise FormImportError(
            "Не удалось найти JSON-состояние формы Яндекса. "
            "Возможно, форма приватная или формат изменился."
        )

    hits: list[dict] = []
    for b in blobs:
        _ya_walk(b, hits)

    # Дедупликация по identity: JSON-дерево после разбора может содержать
    # один и тот же dict на нескольких путях (если был граф). Хешируем
    # по id() — никаких глубоких сравнений.
    seen: set[int] = set()
    uniq: list[dict] = []
    for h in hits:
        k = id(h)
        if k in seen:
            continue
        seen.add(k)
        uniq.append(h)

    title, description = _ya_find_title(blobs)

    questions: list[dict[str, Any]] = []
    pending_break = False
    skipped = 0
    for n in uniq:
        t = _ya_node_type(n)
        if t == "page_break":
            pending_break = True
            continue
        qtype = _YA_TYPE_MAP.get(t or "")
        if qtype is None and t != "page_break":
            skipped += 1
            continue

        q_title = _ya_title(n)
        q_desc = _ya_description(n)

        cfg: dict[str, Any] = {}
        options: list[dict[str, Any]] = []
        if qtype is QuestionType.scale:
            cfg = _ya_scale_config(n)
        elif qtype in (
            QuestionType.single_choice,
            QuestionType.multiple_choice,
            QuestionType.dropdown,
        ):
            options = _ya_options(n)
            if not options:
                skipped += 1
                continue

        questions.append({
            "type": qtype,
            "title": q_title,
            "description": q_desc,
            "page_break_before": pending_break,
            "required": _ya_required(n),
            "config": cfg,
            "options": options,
        })
        pending_break = False

    return title, description, questions, skipped


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

async def import_from_url(
    url: str,
) -> tuple[str, str | None, str | None, list[dict[str, Any]], int]:
    """Возвращает (provider, title, description, questions, skipped) по URL."""
    provider = detect_provider(url)
    html = await _fetch_html(url)
    if provider == "google":
        title, description, questions, skipped = parse_google_form(html)
    else:
        title, description, questions, skipped = parse_yandex_form(html)
    return provider, title, description, questions, skipped
