import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import Answer, Question, Response, Survey, SurveyStatus, User
from ..schemas.response import (
    AnswerOut,
    ResponseOut,
    ResponseStartOut,
    ResponseSubmitIn,
)
from ..schemas.survey import SurveyDetail, SurveyVariantOut
from ..schemas.question import QuestionOut
from ..core.deps import get_optional_user, get_current_user
from ..core.permissions import require_role, get_survey_or_404
from ..core.variant import pick_variant
from ..core.conditional import evaluate
from ..models.collaboration import CollabRole


router = APIRouter(tags=["responses"])


def _public_detail(s: Survey) -> SurveyDetail:
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
        variants=[],
    )


@router.get("/public/surveys/{slug}", response_model=SurveyDetail)
async def get_public_survey(
    slug: str,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> SurveyDetail:
    res = await db.execute(select(Survey).where(Survey.slug == slug))
    survey = res.scalar_one_or_none()
    if not survey:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Опрос не найден")

    if survey.status != SurveyStatus.published:
        if not user or survey.owner_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Опрос недоступен")

    chosen = await pick_variant(db, survey)
    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == chosen.id)
    )
    chosen = res.scalar_one()
    return _public_detail(chosen)


@router.post("/public/surveys/{slug}/start", response_model=ResponseStartOut)
async def start_response(
    slug: str,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> ResponseStartOut:
    res = await db.execute(select(Survey).where(Survey.slug == slug))
    survey = res.scalar_one_or_none()
    if not survey or survey.status != SurveyStatus.published:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Опрос недоступен")

    chosen = await pick_variant(db, survey)

    if chosen.one_response_per_user and user:
        ex = await db.execute(
            select(Response).where(
                Response.survey_id == chosen.id,
                Response.user_id == user.id,
                Response.is_complete.is_(True),
            )
        )
        if ex.scalar_one_or_none():
            raise HTTPException(status.HTTP_409_CONFLICT, "Вы уже проходили этот опрос")

    anon_token = None if (user and not chosen.is_anonymous) else secrets.token_urlsafe(24)
    resp = Response(
        survey_id=chosen.id,
        user_id=None if chosen.is_anonymous else (user.id if user else None),
        anon_token=anon_token,
    )
    db.add(resp)
    await db.commit()
    await db.refresh(resp)
    return ResponseStartOut(response_id=resp.id, survey_id=chosen.id, anon_token=anon_token)


@router.post("/public/responses/{response_id}/submit", response_model=ResponseOut)
async def submit_response(
    response_id: int,
    payload: ResponseSubmitIn,
    user: User | None = Depends(get_optional_user),
    db: AsyncSession = Depends(get_db),
) -> ResponseOut:
    res = await db.execute(
        select(Response).options(selectinload(Response.answers)).where(Response.id == response_id)
    )
    resp = res.scalar_one_or_none()
    if not resp:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Response не найден")
    if resp.is_complete:
        raise HTTPException(status.HTTP_409_CONFLICT, "Уже отправлено")

    res = await db.execute(
        select(Question).options(selectinload(Question.options)).where(Question.survey_id == resp.survey_id)
    )
    questions = {q.id: q for q in res.scalars()}

    answers_map = {a.question_id: a.value for a in payload.answers}

    for q in questions.values():
        visible = evaluate(q.display_condition, answers_map)
        if visible and q.required:
            v = answers_map.get(q.id)
            if v is None or v == {} or v.get("value") in (None, "", []):
                raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Вопрос {q.id} обязателен")

    for a in resp.answers:
        await db.delete(a)
    await db.flush()

    for ans in payload.answers:
        if ans.question_id not in questions:
            continue
        if not evaluate(questions[ans.question_id].display_condition, answers_map):
            continue
        db.add(Answer(response_id=resp.id, question_id=ans.question_id, value=ans.value))

    resp.is_complete = True
    resp.submitted_at = datetime.now(timezone.utc)
    if user and not resp.user_id:
        survey = await db.get(Survey, resp.survey_id)
        if survey and not survey.is_anonymous:
            resp.user_id = user.id
    await db.commit()

    res = await db.execute(
        select(Response).options(selectinload(Response.answers)).where(Response.id == resp.id)
    )
    resp = res.scalar_one()
    return ResponseOut(
        id=resp.id,
        survey_id=resp.survey_id,
        user_id=resp.user_id,
        is_complete=resp.is_complete,
        started_at=resp.started_at,
        submitted_at=resp.submitted_at,
        answers=[AnswerOut(question_id=a.question_id, value=a.value) for a in resp.answers],
    )


@router.get("/surveys/{survey_id}/responses", response_model=list[ResponseOut])
async def list_responses(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ResponseOut]:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.viewer)
    res = await db.execute(
        select(Response)
        .options(selectinload(Response.answers))
        .where(Response.survey_id == survey_id)
        .order_by(Response.started_at.desc())
    )
    out: list[ResponseOut] = []
    for r in res.scalars():
        out.append(ResponseOut(
            id=r.id, survey_id=r.survey_id, user_id=r.user_id,
            is_complete=r.is_complete, started_at=r.started_at, submitted_at=r.submitted_at,
            answers=[AnswerOut(question_id=a.question_id, value=a.value) for a in r.answers],
        ))
    return out
