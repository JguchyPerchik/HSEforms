from collections import Counter
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import Answer, CollabRole, Question, Response, Survey, User
from ..schemas.analytics import QuestionStats, SurveyAnalytics
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role


router = APIRouter(prefix="/surveys/{survey_id}/analytics", tags=["analytics"])


def _value(v: dict):
    if not isinstance(v, dict):
        return v
    return v.get("value", v.get("text"))


@router.get("", response_model=SurveyAnalytics)
async def survey_analytics(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyAnalytics:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.viewer)

    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey_id)
    )
    survey = res.scalar_one()

    res = await db.execute(select(Response).where(Response.survey_id == survey_id))
    responses = list(res.scalars())
    total = len(responses)
    completed = sum(1 for r in responses if r.is_complete)

    q_ids = [q.id for q in survey.questions]
    answers_by_q: dict[int, list[dict]] = {qid: [] for qid in q_ids}
    if q_ids:
        ares = await db.execute(
            select(Answer).where(Answer.question_id.in_(q_ids))
        )
        for a in ares.scalars():
            answers_by_q.setdefault(a.question_id, []).append(a.value)

    stats: list[QuestionStats] = []
    for q in survey.questions:
        bucket = answers_by_q.get(q.id, [])
        dist: dict = {}
        if q.type.value in ("single_choice", "multiple_choice", "dropdown"):
            counter: Counter = Counter()
            for v in bucket:
                val = _value(v)
                if isinstance(val, list):
                    counter.update([str(x) for x in val])
                elif val is not None:
                    counter[str(val)] += 1
            dist = dict(counter)
        elif q.type.value in ("scale", "rating", "number"):
            nums = []
            for v in bucket:
                try:
                    nums.append(float(_value(v)))
                except (TypeError, ValueError):
                    continue
            if nums:
                dist = {
                    "count": len(nums),
                    "avg": sum(nums) / len(nums),
                    "min": min(nums),
                    "max": max(nums),
                    "histogram": dict(Counter(int(round(x)) for x in nums)),
                }
        else:
            dist = {"sample": [str(_value(v)) for v in bucket[:50] if _value(v) is not None]}

        stats.append(QuestionStats(
            question_id=q.id, type=q.type.value, title=q.title,
            total_answers=len(bucket), distribution=dist,
        ))

    return SurveyAnalytics(
        survey_id=survey_id, total_responses=total,
        completed_responses=completed, questions=stats,
    )
