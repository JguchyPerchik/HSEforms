from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import CollabRole, SurveyCollaborator, User
from ..schemas.collaboration import CollaboratorAdd, CollaboratorOut
from ..core.deps import get_current_user
from ..core.permissions import get_survey_or_404, require_role


router = APIRouter(prefix="/surveys/{survey_id}/collaborators", tags=["collaborators"])


@router.get("", response_model=list[CollaboratorOut])
async def list_collaborators(
    survey_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[CollaboratorOut]:
    survey = await get_survey_or_404(db, survey_id)
    await require_role(db, survey, user, CollabRole.viewer)
    res = await db.execute(
        select(SurveyCollaborator, User)
        .join(User, User.id == SurveyCollaborator.user_id)
        .where(SurveyCollaborator.survey_id == survey_id)
    )
    out = []
    for collab, u in res.all():
        out.append(CollaboratorOut(
            id=collab.id, user_id=u.id, role=collab.role, email=u.email, full_name=u.full_name
        ))
    return out


@router.post("", response_model=CollaboratorOut, status_code=201)
async def add_collaborator(
    survey_id: int,
    data: CollaboratorAdd,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollaboratorOut:
    survey = await get_survey_or_404(db, survey_id)
    if survey.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Только владелец управляет коллабораторами")

    res = await db.execute(select(User).where(User.email == data.email))
    target = res.scalar_one_or_none()
    if not target:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Пользователь не найден")
    if target.id == survey.owner_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Это владелец опроса")

    existing = await db.execute(
        select(SurveyCollaborator).where(
            SurveyCollaborator.survey_id == survey_id,
            SurveyCollaborator.user_id == target.id,
        )
    )
    collab = existing.scalar_one_or_none()
    if collab:
        collab.role = data.role
    else:
        collab = SurveyCollaborator(survey_id=survey_id, user_id=target.id, role=data.role)
        db.add(collab)
    await db.commit()
    await db.refresh(collab)
    return CollaboratorOut(id=collab.id, user_id=target.id, role=collab.role, email=target.email, full_name=target.full_name)


@router.delete("/{user_id}", status_code=204)
async def remove_collaborator(
    survey_id: int,
    user_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    survey = await get_survey_or_404(db, survey_id)
    if survey.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Только владелец")
    res = await db.execute(
        select(SurveyCollaborator).where(
            SurveyCollaborator.survey_id == survey_id, SurveyCollaborator.user_id == user_id
        )
    )
    collab = res.scalar_one_or_none()
    if collab:
        await db.delete(collab)
        await db.commit()
