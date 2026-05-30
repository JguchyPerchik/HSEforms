"""Synthetic respondents — generate AI-driven answers for testing surveys."""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..config import settings
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role
from ..core import synthetic as engine
from ..database import SessionLocal, get_db
from ..models import CollabRole, Question, Survey, User
from ..schemas.synthetic import (
    SyntheticRespondentResult,
    SyntheticRunIn,
    SyntheticRunOut,
)


router = APIRouter(prefix="/surveys/{survey_id}/synthetic", tags=["synthetic"])


@router.post("/run", response_model=SyntheticRunOut)
async def run_synthetic(
    survey_id: int,
    payload: SyntheticRunIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyntheticRunOut:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)

    # Validate that the provider selected in env has its key set.
    provider_key_attr = {
        "groq": "GROQ_API_KEY",
        "openrouter": "OPENROUTER_API_KEY",
    }.get(settings.LLM_PROVIDER.lower())
    if not provider_key_attr or not getattr(settings, provider_key_attr, ""):
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            f"Синтетические респонденты не настроены: задайте {provider_key_attr or 'API_KEY'} "
            f"на сервере (LLM_PROVIDER={settings.LLM_PROVIDER!r})",
        )

    if payload.count > settings.SYNTHETIC_MAX_PER_REQUEST:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Слишком много респондентов за раз (макс. {settings.SYNTHETIC_MAX_PER_REQUEST})",
        )

    # Load questions with options for prompt construction.
    res = await db.execute(
        select(Survey)
        .options(selectinload(Survey.questions).selectinload(Question.options))
        .where(Survey.id == survey_id)
    )
    survey = res.scalar_one()
    questions = [q for q in survey.questions
                 if q.type.value not in ("section_header", "file_upload")]
    if not questions:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "В опросе нет вопросов, на которые можно ответить",
        )

    model = (payload.model or settings.LLM_DEFAULT_MODEL).strip()
    persona = payload.persona.model_dump(exclude_none=True)

    results = await engine.run_batch(
        db_factory=SessionLocal,
        survey=survey,
        questions=questions,
        persona=persona,
        model=model,
        count=payload.count,
        concurrency=settings.SYNTHETIC_CONCURRENCY,
    )

    succeeded = sum(1 for r in results if r.ok)
    return SyntheticRunOut(
        requested=payload.count,
        succeeded=succeeded,
        failed=len(results) - succeeded,
        results=[SyntheticRespondentResult(
            ok=r.ok, error=r.error, answers_written=r.answers_written
        ) for r in results],
        model=model,
        persona=persona,
    )
