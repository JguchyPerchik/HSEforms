from typing import Any
from pydantic import BaseModel, Field


class TrendPoint(BaseModel):
    """Одна точка временного тренда: среднее значение ответа в бакете.

    Используется только для числовых вопросов (scale/rating/number) — для
    остальных смысла «среднего» нет, и поле остаётся пустым списком.
    Бакет привязан к началу временного интервала (см. SurveyAnalytics.trend_bin
    — она же определяет шаг этого интервала). Ответы из незавершённых
    респондентов в тренд не попадают (у них нет submitted_at).
    """
    bucket: str   # ISO datetime UTC начала бакета (5min/hour/day/week)
    mean: float
    n: int


class QuestionStats(BaseModel):
    question_id: int
    type: str
    title: str
    total_answers: int
    distribution: dict[str, Any]
    # Per-variant breakdown: "0" = original, "1".."N" = variants, "-1" = skipped.
    by_variant: dict[str, dict[str, Any]] = Field(default_factory=dict)
    # Временной тренд средних значений — пусто для нечисловых вопросов
    # и для вопросов без завершённых ответов. Шаг бакета общий для всего
    # опроса, лежит на родителе (SurveyAnalytics.trend_bin).
    trend: list[TrendPoint] = Field(default_factory=list)


class SurveyAnalytics(BaseModel):
    survey_id: int
    total_responses: int
    completed_responses: int
    # Авто-подобранный шаг тренда на основе разброса submitted_at:
    #   "5min" | "hour" | "day" | "week"
    # Один на весь опрос — иначе невозможно сравнивать тренды разных
    # вопросов между собой. Фронт по этой строке решает, как форматировать
    # подписи оси X (час/минута/день/неделя).
    trend_bin: str = "day"
    questions: list[QuestionStats]
