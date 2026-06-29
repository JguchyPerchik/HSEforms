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
from ..schemas.survey import (
    ImportFromUrlIn,
    ImportFromUrlOut,
    SurveyCreate,
    SurveyDetail,
    SurveySummary,
    SurveyUpdate,
    SurveyVariantOut,
)
from ..schemas.question import QuestionOut
from ..core.deps import get_current_user
from ..core.variant import rr_counter_key
from ..redis_client import redis_client
from ..core.permissions import get_survey_or_404, require_role
from ..services.form_importers import FormImportError, import_from_url
from ..models import QuestionOption


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
        consent_required=s.consent_required,
        consent_text=s.consent_text,
        theme=s.theme or {},
        parent_survey_id=s.parent_survey_id,
        variant_label=s.variant_label,
        variant_weight=s.variant_weight,
        assignment_mode=s.assignment_mode or "random",
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
    # passive_deletes=True на relationships означает, что SQLAlchemy не
    # будет лениво подгружать questions/variants/collaborators перед
    # удалением — каскад выполнит Postgres сам по ON DELETE CASCADE.
    # Без этого флага async-движок падает на MissingGreenlet и DELETE
    # тихо откатывается.
    try:
        await db.delete(survey)
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Не удалось удалить опрос: {e}",
        )


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
        consent_required=src.consent_required,
        consent_text=src.consent_text,
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


@router.post("/{survey_id}/reset_assignment", status_code=204)
async def reset_assignment(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """Сбросить round-robin счётчик опроса.

    После сброса следующий респондент снова получит первый вариант.
    Используется, когда автор закрывает первую волну сбора и хочет
    начать новую с равного распределения.

    На переменные `assignment_mode` или `variant_weight` не влияет.
    """
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)
    # Сбрасываем счётчик у родителя — у вариантов своих счётчиков нет.
    target_id = survey.parent_survey_id or survey.id
    await redis_client.delete(rr_counter_key(target_id))


@router.post("/{survey_id}/import", response_model=ImportFromUrlOut)
async def import_questions(
    survey_id: int,
    payload: ImportFromUrlIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ImportFromUrlOut:
    """Импортировать структуру опроса по публичной ссылке Google Forms
    или Яндекс Форм. Вопросы ДОПИСЫВАЮТСЯ в конец текущего опроса —
    это намеренно: пользователь может импортировать несколько разных
    форм в один проект, или сначала набросать свои вопросы, а потом
    подтянуть демографический блок из чужого опроса. Полная замена
    реализуется в UI (создать новый опрос → импортировать).

    Поддерживаемые типы (см. services/form_importers.py):
      short_text, long_text, single_choice, multiple_choice,
      dropdown, scale, section_header.
    Всё, что не вошло в этот список (сетки, дата/время, file upload,
    изображения, видео и т.п.) — молча пропускается, число пропусков
    возвращается клиенту как skipped_count.
    """
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.editor)

    try:
        provider, _title, _desc, questions, skipped = await import_from_url(payload.url)
    except FormImportError as e:
        # FormImportError — это «корректно опознанная» проблема (плохой URL,
        # форма закрыта, формат сменился). Отдаём 400 с человекочитаемым
        # текстом, чтобы UI мог показать его в snackbar'е без оборачивания.
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(e))
    except Exception as e:  # pragma: no cover
        # Любая другая ошибка (httpx таймаут, неожиданный JSON) — 502:
        # импорт зависит от внешнего сервиса, и это его сбой, а не наш.
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY,
            f"Импорт сорвался на стороне источника: {type(e).__name__}: {e}",
        )

    # Вычисляем стартовую позицию: смотрим максимум среди текущих вопросов
    # ОДНИМ запросом, без подтягивания всего списка в Python.
    from sqlalchemy import func
    last_pos_res = await db.execute(
        select(func.max(Question.position)).where(Question.survey_id == survey_id)
    )
    last_pos = last_pos_res.scalar() or -1

    imported_count = 0
    for q_data in questions:
        last_pos += 1
        # Importer возвращает type как QuestionType enum — это уже готовый
        # объект, не нужно ловить ValueError на неизвестных строках.
        new_q = Question(
            survey_id=survey_id,
            type=q_data["type"],
            title=q_data.get("title") or "",
            description=q_data.get("description"),
            position=last_pos,
            page_break_before=bool(q_data.get("page_break_before")),
            required=bool(q_data.get("required")),
            config=dict(q_data.get("config") or {}),
            display_condition=None,
        )
        db.add(new_q)
        await db.flush()  # нужен id для options

        for opt in q_data.get("options") or []:
            db.add(QuestionOption(
                question_id=new_q.id,
                label=str(opt.get("label") or ""),
                value=str(opt.get("value") or ""),
                position=int(opt.get("position") or 0),
            ))
        imported_count += 1

    await db.commit()

    # Перезагружаем survey с questions+options для ответа — клиент после
    # импорта сразу перерисовывает экран без дополнительного GET.
    detail = await get_survey(survey_id, user, db)
    return ImportFromUrlOut(
        provider=provider,
        imported_count=imported_count,
        skipped_count=skipped,
        survey=detail,
    )
