from collections import Counter, defaultdict
from typing import Any

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import Answer, CollabRole, Question, Response, Survey, User
from ..schemas.analytics import QuestionStats, SurveyAnalytics
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role


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

    # 3. Single query: all answers JOINed with their response (for variant_assignments).
    #    This is the N+1 fix — before, we did one query for responses, then one
    #    query for answers; now it's one trip.
    rows = await db.execute(
        select(Answer.question_id, Answer.value, Response.variant_assignments)
        .join(Response, Response.id == Answer.response_id)
        .where(Response.survey_id == survey_id)
    )

    # bucket[qid][variant_key] = list of values
    bucket: dict[int, dict[str, list]] = defaultdict(lambda: defaultdict(list))
    for qid, value, assignments in rows.all():
        v_idx = (assignments or {}).get(str(qid))
        variant_key = str(v_idx) if v_idx is not None else "0"
        bucket[qid][variant_key].append(value)

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
        stats.append(QuestionStats(
            question_id=q.id, type=q.type.value, title=q.title,
            total_answers=len(combined), distribution=distribution,
            by_variant=by_variant,
        ))

    return SurveyAnalytics(
        survey_id=survey_id, total_responses=total or 0,
        completed_responses=completed or 0, questions=stats,
    )
