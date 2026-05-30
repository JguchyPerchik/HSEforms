from typing import Any
from pydantic import BaseModel, Field


class SyntheticPersona(BaseModel):
    """Demographic profile passed to the LLM as system prompt fodder.
    Every field is optional — omitted ones simply don't appear in the persona."""
    year: int | str | None = None
    gender: str | None = None
    country: str | None = None
    age: int | str | None = None
    education: str | None = None
    income: str | None = None
    occupation: str | None = None
    social_class: str | None = None
    marital_status: str | None = None
    children: int | str | None = None
    religion: str | None = None
    language: str | None = None


class SyntheticRunIn(BaseModel):
    persona: SyntheticPersona = Field(default_factory=SyntheticPersona)
    count: int = Field(default=1, ge=1, le=200)
    model: str | None = None  # falls back to OPENROUTER_DEFAULT_MODEL


class SyntheticRespondentResult(BaseModel):
    ok: bool
    error: str | None = None
    answers_written: int = 0


class SyntheticRunOut(BaseModel):
    requested: int
    succeeded: int
    failed: int
    results: list[SyntheticRespondentResult]
    model: str
    persona: dict[str, Any]
