from typing import Any
from pydantic import BaseModel, Field

from ..models.question import QuestionType


class OptionIn(BaseModel):
    id: int | None = None
    label: str = ""
    value: str = ""
    position: int = 0


class OptionOut(BaseModel):
    id: int
    label: str
    value: str
    position: int

    class Config:
        from_attributes = True


class QuestionIn(BaseModel):
    type: QuestionType
    title: str = ""
    description: str | None = None
    position: int = 0
    page_break_before: bool = False
    required: bool = False
    config: dict[str, Any] = Field(default_factory=dict)
    display_condition: dict[str, Any] | None = None
    options: list[OptionIn] = Field(default_factory=list)


class QuestionUpdate(BaseModel):
    type: QuestionType | None = None
    title: str | None = None
    description: str | None = None
    page_break_before: bool | None = None
    required: bool | None = None
    config: dict[str, Any] | None = None
    display_condition: dict[str, Any] | None = None
    options: list[OptionIn] | None = None


class QuestionOut(BaseModel):
    id: int
    survey_id: int
    type: QuestionType
    title: str
    description: str | None
    position: int
    page_break_before: bool
    required: bool
    config: dict[str, Any]
    display_condition: dict[str, Any] | None
    options: list[OptionOut]

    class Config:
        from_attributes = True


class ReorderIn(BaseModel):
    question_ids: list[int]
