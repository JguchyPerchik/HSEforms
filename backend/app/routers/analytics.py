from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import Answer, CollabRole, Question, Response, Survey, User
from ..schemas.analytics import QuestionStats, SurveyAnalytics, TrendPoint
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role


# ─────────────────────────── временной тренд ────────────────────────────

def _pick_bin(min_ts: datetime | None, max_ts: datetime | None) -> tuple[str, timedelta]:
    """Подбирает шаг бакета по разбросу submitted_at завершённых ответов.

    Логика — «чтобы на графике было не меньше ~5 и не больше ~100 точек».
    Если разброс < 2 ч → 5-минутные бакеты (типичный «опрос в чате на час»),
    если < 1 дня → часовые (опрос за смену/день), если < 60 дней → дневные
    (стандарт «месяц сбора данных»), иначе — недельные (для долгих треков).
    """
    if min_ts is None or max_ts is None:
        return ("day", timedelta(days=1))
    span = max_ts - min_ts
    if span < timedelta(hours=2):
        return ("5min", timedelta(minutes=5))
    if span < timedelta(days=1):
        return ("hour", timedelta(hours=1))
    if span < timedelta(days=60):
        return ("day", timedelta(days=1))
    return ("week", timedelta(weeks=1))


def _bucket_start(ts: datetime, bin_name: str) -> datetime:
    """Округляет timestamp ВНИЗ к началу бакета. Все вычисления в UTC,
    чтобы при смене часового пояса на клиенте подписи оставались осмыслены
    (фронт сам сдвинет в local time при отображении, если захочет).
    """
    ts = ts.astimezone(timezone.utc)
    if bin_name == "5min":
        return ts.replace(minute=(ts.minute // 5) * 5, second=0, microsecond=0)
    if bin_name == "hour":
        return ts.replace(minute=0, second=0, microsecond=0)
    if bin_name == "day":
        return ts.replace(hour=0, minute=0, second=0, microsecond=0)
    if bin_name == "week":
        # Округляем к понедельнику 00:00 UTC.
        midnight = ts.replace(hour=0, minute=0, second=0, microsecond=0)
        return midnight - timedelta(days=midnight.weekday())
    # Fallback — без округления; не должно случаться.
    return ts


router = APIRouter(prefix="/surveys/{survey_id}/analytics", tags=["analytics"])


def _value(v: Any):
    if not isinstance(v, dict):
        return v
    return v.get("value", v.get("text"))


def _aggregate(qtype: str, options_meta: list[dict], bucket: list[Any]) -> dict:
    """Type-specific aggregation. `bucket` is a list of `Answer.value` dicts."""
    if qtype in ("single_choice", "multiple_choice", "dropdown"):
        counter: Counter = Counter()
        for v in bucket:
            val = _value(v)
            if isinstance(val, list):
                counter.update([str(x) for x in val])
            elif val is not None:
                counter[str(val)] += 1
        return dict(counter)
    if qtype in ("scale", "rating", "number"):
        nums = []
        for v in bucket:
            try:
                nums.append(float(_value(v)))
            except (TypeError, ValueError):
                continue
        if not nums:
            return {}
        return {
            "count": len(nums),
            "avg": sum(nums) / len(nums),
            "min": min(nums),
            "max": max(nums),
            "histogram": dict(Counter(int(round(x)) for x in nums)),
        }
    return {"sample": [str(_value(v)) for v in bucket[:50] if _value(v) is not None]}


@router.get("", response_model=SurveyAnalytics)
async def survey_analytics(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyAnalytics:
    """Aggregations with per-variant split.

    Variants are detected from `Response.variant_assignments` (filled by client
    at /submit). For each question we report:
        - distribution: combined (legacy, easy to consume)
        - by_variant: dict {"0": <distribution>, "1": <distribution>, ...}
                      "0" = original; "1".."N" = per-question variants;
                      "-1" = skipped (always empty distribution, kept for count)
    """
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.viewer)

    # 1. Load survey with questions+options in one query.
    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey_id)
    )
    survey = res.scalar_one()

    # 2. One aggregate query for response counts.
    total_q = await db.execute(
        select(
            func.count(Response.id),
            func.count(Response.id).filter(Response.is_complete.is_(True)),
        ).where(Response.survey_id == survey_id)
    )
    total, completed = total_q.one()

    # 2a. Времена прохождения — отдельный лёгкий запрос. Тащим только
    #     started_at/submitted_at завершённых respond'ов. Делать через
    #     основной запрос (п.3) нельзя: он джойнит по answers, и каждый
    #     response повторился бы N раз = неправильное среднее.
    timing_rows = await db.execute(
        select(Response.started_at, Response.submitted_at).where(
            Response.survey_id == survey_id,
            Response.is_complete.is_(True),
            Response.submitted_at.is_not(None),
        )
    )
    durations: list[float] = []
    for started_at, submitted_at in timing_rows.all():
        delta = (submitted_at - started_at).total_seconds()
        # Отрицательная разница — мусор/баг кеша часов. Игнорируем.
        if delta < 0:
            continue
        durations.append(delta)

    # Медиана — на всём массиве, она устойчива к выбросам.
    # Среднее — с обрезкой выбросов > 4 ч, иначе один забытый таб
    # ломает метрику. 4 ч выбраны эвристически: длиннее реального опроса,
    # короче «оставил с утра, открыл вечером».
    median_seconds: int | None = None
    avg_seconds: int | None = None
    if durations:
        sorted_d = sorted(durations)
        mid = len(sorted_d) // 2
        median_val = (
            sorted_d[mid]
            if len(sorted_d) % 2 == 1
            else (sorted_d[mid - 1] + sorted_d[mid]) / 2
        )
        median_seconds = int(round(median_val))

        clean = [d for d in durations if d <= 4 * 3600]
        if clean:
            avg_seconds = int(round(sum(clean) / len(clean)))

    # 3. Single query: все ответы, JOIN'нутые с их response. К существующему
    #    набору (qid, value, variant_assignments) добавляем submitted_at +
    #    is_complete — нужны для построения временного тренда. Один трип
    #    в БД покрывает и распределения, и тренд.
    rows = await db.execute(
        select(
            Answer.question_id,
            Answer.value,
            Response.variant_assignments,
            Response.submitted_at,
            Response.is_complete,
        )
        .join(Response, Response.id == Answer.response_id)
        .where(Response.survey_id == survey_id)
    )
    all_rows = rows.all()  # материализуем — нужно пройти дважды

    # bucket[qid][variant_key] = list of values  (для распределений)
    bucket: dict[int, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    # trend_bucket[qid][bucket_start] = list of numeric values
    # Заполняется ТОЛЬКО из is_complete=True ответов с непустым submitted_at.
    trend_bucket: dict[int, dict[datetime, list[float]]] = defaultdict(
        lambda: defaultdict(list)
    )

    # Сначала определим разброс времени по всем завершённым ответам, чтобы
    # выбрать гранулярность бакета. Заодно соберём raw-значения для основной
    # агрегации (это нужно делать в любом случае).
    submitted_ts: list[datetime] = []
    for qid, value, assignments, submitted_at, is_complete in all_rows:
        v_idx = (assignments or {}).get(str(qid))
        variant_key = str(v_idx) if v_idx is not None else "0"
        bucket[qid][variant_key].append(value)
        if is_complete and submitted_at is not None:
            submitted_ts.append(submitted_at)

    bin_name, _bin_size = _pick_bin(
        min(submitted_ts) if submitted_ts else None,
        max(submitted_ts) if submitted_ts else None,
    )

    # Второй проход: бакетизация только числовых ответов из завершённых
    # response'ов. Это можно было склеить в первый цикл, но тогда мы бы
    # не знали bin_name до конца — пришлось бы хранить timestamps вместе
    # с числовыми значениями и группировать постфактум. Два прохода
    # читабельнее и стоят 0 трипов в БД.
    for qid, value, _assignments, submitted_at, is_complete in all_rows:
        if not is_complete or submitted_at is None:
            continue
        val = _value(value)
        try:
            num = float(val)
        except (TypeError, ValueError):
            continue
        b_start = _bucket_start(submitted_at, bin_name)
        trend_bucket[qid][b_start].append(num)

    stats: list[QuestionStats] = []
    for q in survey.questions:
        opts_meta = [{"value": o.value, "label": o.label} for o in q.options]
        per_variant = bucket.get(q.id, {})
        # Combined distribution (all variants together) for backward compat.
        combined: list = []
        for v_list in per_variant.values():
            combined.extend(v_list)
        distribution = _aggregate(q.type.value, opts_meta, combined)
        by_variant: dict[str, dict] = {
            v_key: _aggregate(q.type.value, opts_meta, v_list)
            for v_key, v_list in per_variant.items()
        }

        # Тренд считаем только для числовых типов — для текстов/категорий
        # «среднее» бессмысленно. Сортируем по времени бакета.
        trend_list: list[TrendPoint] = []
        if q.type.value in ("scale", "rating", "number"):
            for b_ts, vals in sorted(trend_bucket.get(q.id, {}).items()):
                trend_list.append(TrendPoint(
                    bucket=b_ts.isoformat(),
                    mean=sum(vals) / len(vals),
                    n=len(vals),
                ))

        stats.append(QuestionStats(
            question_id=q.id, type=q.type.value, title=q.title,
            total_answers=len(combined), distribution=distribution,
            by_variant=by_variant, trend=trend_list,
        ))

    return SurveyAnalytics(
        survey_id=survey_id, total_responses=total or 0,
        completed_responses=completed or 0,
        trend_bin=bin_name,
        median_completion_seconds=median_seconds,
        avg_completion_seconds=avg_seconds,
        questions=stats,
    )
