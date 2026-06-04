import enum
import secrets
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class SurveyStatus(str, enum.Enum):
    draft = "draft"
    published = "published"
    closed = "closed"


def _gen_slug() -> str:
    return secrets.token_urlsafe(8)
    


class Survey(Base):
    __tablename__ = "surveys"

    id: Mapped[int] = mapped_column(primary_key=True)
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)

    title: Mapped[str] = mapped_column(String(500), default="Без названия")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    slug: Mapped[str] = mapped_column(String(32), unique=True, index=True, default=_gen_slug)

    status: Mapped[SurveyStatus] = mapped_column(
        Enum(SurveyStatus, name="survey_status"), default=SurveyStatus.draft, index=True
    )

    is_anonymous: Mapped[bool] = mapped_column(Boolean, default=True)
    one_response_per_user: Mapped[bool] = mapped_column(Boolean, default=False)
    allow_back_navigation: Mapped[bool] = mapped_column(Boolean, default=True)
    show_progress: Mapped[bool] = mapped_column(Boolean, default=True)

    theme: Mapped[dict] = mapped_column(
        JSONB,
        default=lambda: {
            "primary": "#0F2D69",
            "secondary": "#234B9B",
            "muted": "#929292",
            "border": "#C6C6C6",
            "surface": "#E6E6E6",
            "background": "#FFFFFF",
            "font": "Inter",
        },
    )

    parent_survey_id: Mapped[int | None] = mapped_column(
        ForeignKey("surveys.id", ondelete="CASCADE"), nullable=True, index=True
    )
    variant_weight: Mapped[float] = mapped_column(Float, default=1.0)
    variant_label: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Как раздавать варианты респондентам:
    #   "random"      — взвешенный случайный выбор по variant_weight (дефолт)
    #   "round_robin" — детерминированный круг через Redis INCR.
    # Для дочерних опросов-вариантов поле не используется.
    assignment_mode: Mapped[str] = mapped_column(String(20), default="random")

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # passive_deletes=True во всех трёх отношениях критично для async-SQLAlchemy:
    # без этого флага `db.delete(survey)` пытается лениво подгрузить
    # коллекции, чтобы каскадно пометить детей на удаление. В async-режиме
    # ленивый load запрещён → транзакция падает молча → DELETE не уходит.
    # Все FK на эти таблицы уже имеют `ondelete="CASCADE"`, поэтому
    # Postgres сам удалит зависимые строки.
    questions: Mapped[list["Question"]] = relationship(
        back_populates="survey",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="Question.position",
    )
    variants: Mapped[list["Survey"]] = relationship(
        "Survey",
        backref="parent",
        remote_side="Survey.id",
        cascade="all",
        passive_deletes=True,
    )
    collaborators: Mapped[list["SurveyCollaborator"]] = relationship(
        back_populates="survey",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
