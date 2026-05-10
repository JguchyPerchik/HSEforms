from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models import CollabRole, Question, QuestionOption, Survey, User
from ..schemas.question import QuestionIn, QuestionOut, QuestionUpdate, ReorderIn
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role


router = APIRouter(prefix="/surveys/{survey_id}/questions", tags=["questions"])


async def _load_question(db: AsyncSession, survey_id: int, question_id: int) -> Question:
    res = await db.execute(
        select(Question)
        .options(selectinload(Question.options))
        .where(Question.id == question_id, Question.survey_id == survey_id)
    )
    q = res.scalar_one_or_none()
    if not q:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Вопрос не найден")
    return q


@router.patch("/reorder", response_model=list[QuestionOut])
async def reorder(
    survey_id: int,
    data: ReorderIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[QuestionOut]:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)

    res = await db.execute(
        select(Question).options(selectinload(Question.options)).where(Question.survey_id == survey_id)
    )
    questions = {q.id: q for q in res.scalars()}
    ids = data.question_ids
    if set(ids) != set(questions.keys()):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Список ID не совпадает с вопросами опроса")

    for idx, qid in enumerate(ids):
        questions[qid].position = idx
    await db.commit()
    return [QuestionOut.model_validate(questions[qid]) for qid in ids]


@router.post("", response_model=QuestionOut, status_code=201)
async def add_question(
    survey_id: int,
    data: QuestionIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> QuestionOut:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)

    res = await db.execute(
        select(Question.position).where(Question.survey_id == survey_id).order_by(Question.position.desc()).limit(1)
    )
    last = res.scalar()
    position = data.position or ((last or 0) + 1)

    q = Question(
        survey_id=survey_id,
        type=data.type,
        title=data.title,
        description=data.description,
        position=position,
        page_break_before=data.page_break_before,
        required=data.required,
        config=data.config,
        display_condition=data.display_condition,
    )
    db.add(q)
    await db.flush()
    for i, opt in enumerate(data.options):
        db.add(QuestionOption(question_id=q.id, label=opt.label, value=opt.value or opt.label, position=opt.position or i))
    await db.commit()
    return QuestionOut.model_validate(await _load_question(db, survey_id, q.id))


@router.patch("/{question_id}", response_model=QuestionOut)
async def update_question(
    survey_id: int,
    question_id: int,
    data: QuestionUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> QuestionOut:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)
    q = await _load_question(db, survey_id, question_id)

    updates = data.model_dump(exclude_unset=True)
    options = updates.pop("options", None)
    for k, v in updates.items():
        setattr(q, k, v)

    if options is not None:
        for opt in q.options:
            await db.delete(opt)
        await db.flush()
        for i, opt in enumerate(options):
            db.add(QuestionOption(
                question_id=q.id,
                label=opt.get("label", ""),
                value=opt.get("value") or opt.get("label", ""),
                position=opt.get("position", i),
            ))
    await db.commit()
    return QuestionOut.model_validate(await _load_question(db, survey_id, question_id))


@router.delete("/{question_id}", status_code=204)
async def delete_question(
    survey_id: int,
    question_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)
    q = await _load_question(db, survey_id, question_id)
    await db.delete(q)
    await db.commit()
