import enum
from sqlalchemy import Boolean, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class QuestionType(str, enum.Enum):
    short_text = "short_text"
    long_text = "long_text"
    single_choice = "single_choice"
    multiple_choice = "multiple_choice"
    dropdown = "dropdown"
    scale = "scale"
    rating = "rating"
    number = "number"
    date = "date"
    time = "time"
    email = "email"
    file_upload = "file_upload"
    section_header = "section_header"


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[int] = mapped_column(primary_key=True)
    survey_id: Mapped[int] = mapped_column(
        ForeignKey("surveys.id", ondelete="CASCADE"), index=True
    )
    type: Mapped[QuestionType] = mapped_column(Enum(QuestionType, name="question_type"))

    title: Mapped[str] = mapped_column(Text, default="")
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    position: Mapped[int] = mapped_column(Integer, default=0, index=True)
    page_break_before: Mapped[bool] = mapped_column(Boolean, default=False)

    required: Mapped[bool] = mapped_column(Boolean, default=False)

    config: Mapped[dict] = mapped_column(JSONB, default=dict)
    display_condition: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    media_url: Mapped[str | None] = mapped_column(String(2000), nullable=True)

    survey: Mapped["Survey"] = relationship(back_populates="questions")
    options: Mapped[list["QuestionOption"]] = relationship(
        back_populates="question", cascade="all, delete-orphan", order_by="QuestionOption.position"
    )


class QuestionOption(Base):
    __tablename__ = "question_options"

    id: Mapped[int] = mapped_column(primary_key=True)
    question_id: Mapped[int] = mapped_column(
        ForeignKey("questions.id", ondelete="CASCADE"), index=True
    )
    label: Mapped[str] = mapped_column(Text, default="")
    value: Mapped[str] = mapped_column(String(255), default="")
    position: Mapped[int] = mapped_column(Integer, default=0)
    media_url: Mapped[str | None] = mapped_column(String(2000), nullable=True)

    question: Mapped[Question] = relationship(back_populates="options")
