from pydantic import BaseModel, EmailStr

from ..models.collaboration import CollabRole


class CollaboratorAdd(BaseModel):
    email: EmailStr
    role: CollabRole = CollabRole.editor


class CollaboratorOut(BaseModel):
    id: int
    user_id: int
    role: CollabRole
    email: str | None = None
    full_name: str | None = None

    class Config:
        from_attributes = True
