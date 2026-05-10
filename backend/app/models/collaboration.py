import enum

from sqlalchemy import Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class CollabRole(str, enum.Enum):
    owner = "owner"
    editor = "editor"
    viewer = "viewer"


class SurveyCollaborator(Base):
    __tablename__ = "survey_collaborators"
    __table_args__ = (UniqueConstraint("survey_id", "user_id", name="uq_survey_user"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    survey_id: Mapped[int] = mapped_column(ForeignKey("surveys.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    role: Mapped[CollabRole] = mapped_column(Enum(CollabRole, name="collab_role"), default=CollabRole.editor)

    survey: Mapped["Survey"] = relationship(back_populates="collaborators")
