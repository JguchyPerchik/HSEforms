from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import Survey, SurveyCollaborator, CollabRole, User


_ROLE_RANK = {CollabRole.viewer: 1, CollabRole.editor: 2, CollabRole.owner: 3}


async def survey_role(db: AsyncSession, survey: Survey, user: User | None) -> CollabRole | None:
    if user is None:
        return None
    if survey.owner_id == user.id:
        return CollabRole.owner
    res = await db.execute(
        select(SurveyCollaborator).where(
            SurveyCollaborator.survey_id == survey.id,
            SurveyCollaborator.user_id == user.id,
        )
    )
    collab = res.scalar_one_or_none()
    return collab.role if collab else None


async def require_role(
    db: AsyncSession, survey: Survey, user: User | None, min_role: CollabRole
) -> CollabRole:
    role = await survey_role(db, survey, user)
    if role is None or _ROLE_RANK[role] < _ROLE_RANK[min_role]:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Недостаточно прав")
    return role


async def get_survey_or_404(db: AsyncSession, survey_id: int) -> Survey:
    survey = await db.get(Survey, survey_id)
    if not survey:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Опрос не найден")
    return survey
