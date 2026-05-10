from typing import Any
from pydantic import BaseModel


class QuestionStats(BaseModel):
    question_id: int
    type: str
    title: str
    total_answers: int
    distribution: dict[str, Any]


class SurveyAnalytics(BaseModel):
    survey_id: int
    total_responses: int
    completed_responses: int
    questions: list[QuestionStats]
