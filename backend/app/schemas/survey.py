from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field

from ..models.survey import SurveyStatus
from .question import QuestionOut


class SurveyCreate(BaseModel):
    title: str = "Без названия"
    description: str | None = None
    is_anonymous: bool = True
    one_response_per_user: bool = False
    allow_back_navigation: bool = True
    show_progress: bool = True
    theme: dict[str, Any] | None = None
    parent_survey_id: int | None = None
    variant_weight: float = 1.0
    variant_label: str | None = None


class SurveyUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    status: SurveyStatus | None = None
    is_anonymous: bool | None = None
    one_response_per_user: bool | None = None
    allow_back_navigation: bool | None = None
    show_progress: bool | None = None
    theme: dict[str, Any] | None = None
    variant_weight: float | None = None
    variant_label: str | None = None


class SurveySummary(BaseModel):
    id: int
    owner_id: int
    title: str
    description: str | None
    slug: str
    status: SurveyStatus
    is_anonymous: bool
    parent_survey_id: int | None
    variant_label: str | None
    variant_weight: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SurveyDetail(SurveySummary):
    one_response_per_user: bool
    allow_back_navigation: bool
    show_progress: bool
    theme: dict[str, Any]
    questions: list[QuestionOut] = Field(default_factory=list)
    variants: list["SurveyVariantOut"] = Field(default_factory=list)


class SurveyVariantOut(BaseModel):
    id: int
    title: str
    variant_label: str | None
    variant_weight: float

    class Config:
        from_attributes = True


SurveyDetail.model_rebuild()
