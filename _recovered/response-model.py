from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class Response(Base):
    __tablename__ = "responses"

    id: Mapped[int] = mapped_column(primary_key=True)
    survey_id: Mapped[int] = mapped_column(
        ForeignKey("surveys.id", ondelete="CASCADE"), index=True
    )
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    anon_token: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)

    is_complete: Mapped[bool] = mapped_column(Boolean, default=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Map question_id (str — JSON keys are strings) -> variant index.
    # 0 = original, 1..N = variants[N-1], -1 = skipped.
    # Filled by /submit from client-side deterministic picks.
    variant_assignments: Mapped[dict] = mapped_column(JSONB, default=dict)

    answers: Mapped[list["Answer"]] = relationship(
        back_populates="response", cascade="all, delete-orphan"
    )


class Answer(Base):
    __tablename__ = "answers"

    id: Mapped[int] = mapped_column(primary_key=True)
    response_id: Mapped[int] = mapped_column(
        ForeignKey("responses.id", ondelete="CASCADE"), index=True
    )
    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), index=True
    )
    value: Mapped[dict] = mapped_column(JSONB, default=dict)

    response: Mapped[Response] = relationship(back_populates="answers")
