from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field


class AnswerIn(BaseModel):
    question_id: int
    value: dict[str, Any] = Field(default_factory=dict)


class ResponseStartIn(BaseModel):
    pass


class ResponseStartOut(BaseModel):
    response_id: int
    survey_id: int
    anon_token: str | None = None


class AnswerOut(BaseModel):
    question_id: int
    value: dict[str, Any]

    class Config:
        from_attributes = True


class ResponseSubmitIn(BaseModel):
    answers: list[AnswerIn]


class ResponseOut(BaseModel):
    id: int
    survey_id: int
    user_id: int | None
    is_complete: bool
    started_at: datetime
    submitted_at: datetime | None
    answers: list[AnswerOut]

    class Config:
        from_attributes = True
