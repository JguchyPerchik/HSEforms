from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import (
    CollabRole,
    Survey,
    SurveyCollaborator,
    SurveyStatus,
    User,
    Question,
)
from ..schemas.survey import SurveyCreate, SurveyDetail, SurveySummary, SurveyUpdate, SurveyVariantOut
from ..schemas.question import QuestionOut
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role


router = APIRouter(prefix="/surveys", tags=["surveys"])


def _to_detail(s: Survey, variants: list[Survey]) -> SurveyDetail:
    return SurveyDetail(
        id=s.id,
        owner_id=s.owner_id,
        title=s.title,
        description=s.description,
        slug=s.slug,
        status=s.status,
        is_anonymous=s.is_anonymous,
        one_response_per_user=s.one_response_per_user,
        allow_back_navigation=s.allow_back_navigation,
        show_progress=s.show_progress,
        theme=s.theme or {},
        parent_survey_id=s.parent_survey_id,
        variant_label=s.variant_label,
        variant_weight=s.variant_weight,
        created_at=s.created_at,
        updated_at=s.updated_at,
        questions=[QuestionOut.model_validate(q) for q in s.questions],
        variants=[SurveyVariantOut.model_validate(v) for v in variants],
    )


@router.post("", response_model=SurveyDetail, status_code=201)
async def create_survey(
    data: SurveyCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyDetail:
    if data.parent_survey_id:
        parent = await get_survey_or_404(db, data.parent_survey_id)
        await require_role(db, parent, user, CollabRole.editor)

    payload = data.model_dump(exclude_unset=True)
    if "theme" not in payload or payload["theme"] is None:
        payload.pop("theme", None)
    survey = Survey(owner_id=user.id, **payload)
    db.add(survey)
    await db.commit()
    await db.refresh(survey)

    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey.id)
    )
    survey = res.scalar_one()
    return _to_detail(survey, [])


@router.get("", response_model=list[SurveySummary])
async def list_my_surveys(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[SurveySummary]:
    q = (
        select(Survey)
        .outerjoin(SurveyCollaborator, SurveyCollaborator.survey_id == Survey.id)
        .where(or_(Survey.owner_id == user.id, SurveyCollaborator.user_id == user.id))
        .where(Survey.parent_survey_id.is_(None))
        .order_by(Survey.updated_at.desc())
    )
    res = await db.execute(q)
    surveys = list({s.id: s for s in res.scalars()}.values())
    return [SurveySummary.model_validate(s) for s in surveys]


@router.get("/{survey_id}", response_model=SurveyDetail)
async def get_survey(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyDetail:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.viewer)

    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey_id)
    )
    survey = res.scalar_one()
    res2 = await db.execute(select(Survey).where(Survey.parent_survey_id == survey_id))
    variants = list(res2.scalars())
    return _to_detail(survey, variants)


@router.patch("/{survey_id}", response_model=SurveyDetail)
async def update_survey(
    survey_id: int,
    data: SurveyUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyDetail:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)

    updates = data.model_dump(exclude_unset=True)
    if updates.get("status") == SurveyStatus.published and survey.published_at is None:
        survey.published_at = datetime.now(timezone.utc)
    for k, v in updates.items():
        setattr(survey, k, v)
    await db.commit()
    return await get_survey(survey_id, user, db)


@router.delete("/{survey_id}", status_code=204)
async def delete_survey(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    survey = await get_survey_or_404(db, survey_id)
    if survey.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Только владелец может удалить опрос")
    await db.delete(survey)
    await db.commit()


@router.post("/{survey_id}/duplicate", response_model=SurveyDetail)
async def duplicate_survey(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyDetail:
    src = await get_survey_or_404(db, survey_id)
    await require_role(db, src, user, CollabRole.viewer)

    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey_id)
    )
    src = res.scalar_one()

    copy = Survey(
        owner_id=user.id,
        title=src.title + " (копия)",
        description=src.description,
        is_anonymous=src.is_anonymous,
        one_response_per_user=src.one_response_per_user,
        allow_back_navigation=src.allow_back_navigation,
        show_progress=src.show_progress,
        theme=dict(src.theme or {}),
    )
    db.add(copy)
    await db.flush()

    from ..models import QuestionOption
    for q in src.questions:
        nq = Question(
            survey_id=copy.id,
            type=q.type,
            title=q.title,
            description=q.description,
            position=q.position,
            page_break_before=q.page_break_before,
            required=q.required,
            config=dict(q.config or {}),
            display_condition=dict(q.display_condition) if q.display_condition else None,
        )
        db.add(nq)
        await db.flush()
        for opt in q.options:
            db.add(QuestionOption(question_id=nq.id, label=opt.label, value=opt.value, position=opt.position))
    await db.commit()
    return await get_survey(copy.id, user, db)
