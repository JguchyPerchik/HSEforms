from typing import Any
from pydantic import BaseModel, Field


class QuestionStats(BaseModel):
    question_id: int
    type: str
    title: str
    total_answers: int
    distribution: dict[str, Any]
    # Per-variant breakdown: "0" = original, "1".."N" = variants, "-1" = skipped.
    by_variant: dict[str, dict[str, Any]] = Field(default_factory=dict)


class SurveyAnalytics(BaseModel):
    survey_id: int
    total_responses: int
    completed_responses: int
    questions: list[QuestionStats]
