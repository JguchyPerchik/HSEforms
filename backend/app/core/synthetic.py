"""Synthetic respondent engine.

Pipeline per respondent:
    persona dict (researcher-supplied)
    + survey questions
    → system + user prompts
    → OpenRouter chat (JSON-mode)
    → parse + normalize values per question type
    → INSERT Response (is_synthetic=true, synthetic_profile=persona) + Answers

All errors are captured per-respondent so a batch of N keeps producing what it can.
"""
from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from ..models import Answer, Question, QuestionType, Response, Survey
from . import llm


# ──────────────────────────────────────────────────────────────────────────
# Prompt construction
# ──────────────────────────────────────────────────────────────────────────

# Persona keys we render into the system prompt — in display order.
# Values come from researcher input (free text) so personas remain flexible.
PERSONA_FIELDS: tuple[str, ...] = (
    "year", "gender", "country", "age", "education", "income",
    "occupation", "social_class", "marital_status", "children",
    "religion", "language",
)


def build_system_prompt(persona: dict[str, Any]) -> str:
    p = {k: persona.get(k) for k in PERSONA_FIELDS}
    lines: list[str] = []

    if p["year"]: lines.append(f"It is the year {p['year']}.")
    parts = []
    if p["age"]: parts.append(f"a {p['age']}-year-old")
    if p["gender"]: parts.append(p["gender"])
    person_clause = " ".join(parts) if parts else "a person"
    where = f" living in {p['country']}" if p["country"] else ""
    lines.append(f"You are {person_clause}{where}.")

    if p["education"]: lines.append(f"Your education is {p['education']}.")
    if p["income"]: lines.append(f"Your income level is {p['income']}.")
    if p["occupation"]: lines.append(f"Your occupational group is {p['occupation']}.")
    if p["social_class"]: lines.append(f"Your social class is {p['social_class']}.")
    if p["marital_status"]: lines.append(f"Your marital status is {p['marital_status']}.")
    if p["children"] is not None and str(p["children"]).strip() != "":
        lines.append(f"You have {p['children']} children.")
    if p["religion"]: lines.append(f"Your religion is {p['religion']}.")
    if p["language"]: lines.append(f"You speak {p['language']} language.")

    lines.extend([
        "",
        "You are participating in a research survey.",
        "Answer every applicable question HONESTLY and CONSISTENTLY as this person would.",
        "Stay in character throughout; do NOT break the persona, refuse, or moralise.",
        "If asked about open-ended things, answer in the persona's language unless the question text dictates otherwise.",
        "",
        "Reply ONLY with strict JSON (no markdown fences, no commentary) of the form:",
        '{"answers": [{"question_id": <int>, "value": <answer>}, ...]}',
        "",
        "Value format per question type:",
        "  - single_choice / dropdown: the chosen option's `value` string",
        "  - multiple_choice: array of chosen option `value` strings",
        "  - scale / rating / number: integer (within the specified range for scale)",
        "  - short_text / long_text / email: string",
        "  - date: 'YYYY-MM-DD'",
        "  - time: 'HH:MM' (24h)",
        "  - file_upload / section_header: omit entirely",
    ])
    return "\n".join(lines)


def build_user_prompt(questions: list[Question]) -> str:
    lines: list[str] = ["Survey questions:", ""]
    for q in questions:
        t = q.type.value
        if t in ("section_header", "file_upload"):
            # Headers carry no answer; file uploads can't be done by AI.
            continue
        head = f"Q{q.id} [{t}]"
        if q.required:
            head += " *required*"
        lines.append(f"{head}: {q.title or '(no title)'}")
        if q.description:
            lines.append(f"  context: {q.description}")
        if t in ("single_choice", "multiple_choice", "dropdown"):
            for o in q.options:
                label = (o.label or o.value or "").strip()
                lines.append(f"  - value={o.value!r}: {label}")
        elif t == "scale":
            mn = int(q.config.get("min", 1) or 1)
            mx = int(q.config.get("max", 5) or 5)
            lines.append(f"  range: integer {mn}..{mx}")
        elif t == "rating":
            lines.append("  range: integer 1..5")
        lines.append("")
    lines.append('Reply: {"answers": [...]}')
    return "\n".join(lines)


# ──────────────────────────────────────────────────────────────────────────
# Response parsing & normalisation
# ──────────────────────────────────────────────────────────────────────────

def _extract_json(text: str) -> dict:
    """Lenient JSON extractor — strips markdown fences and finds the first {...}."""
    s = text.strip()
    if s.startswith("```"):
        s = re.sub(r"^```[a-zA-Z]*\s*", "", s)
        s = re.sub(r"\s*```$", "", s)
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        m = re.search(r"\{.*\}", s, re.DOTALL)
        if not m:
            raise
        return json.loads(m.group(0))


def _normalize(qtype: QuestionType, option_values: set[str], raw: Any) -> Any | None:
    """Coerce model output into the canonical Answer.value payload for the type.

    Returns the normalised primitive, or None to skip the answer (invalid/missing).
    """
    if raw is None:
        return None
    t = qtype.value

    if t in ("short_text", "long_text", "email"):
        return str(raw).strip() or None

    if t in ("number", "scale", "rating"):
        if isinstance(raw, bool):
            return None
        try:
            n = int(round(float(raw)))
            return n
        except (TypeError, ValueError):
            return None

    if t == "date":
        s = str(raw).strip()
        try:
            datetime.strptime(s, "%Y-%m-%d")
            return s
        except ValueError:
            return None

    if t == "time":
        s = str(raw).strip()
        if re.fullmatch(r"\d{1,2}:\d{2}", s):
            h, m = s.split(":")
            return f"{int(h):02d}:{int(m):02d}"
        return None

    if t in ("single_choice", "dropdown"):
        s = str(raw).strip()
        # Accept either exact value or fuzzy match against options
        if s in option_values:
            return s
        for v in option_values:
            if s.lower() == v.lower():
                return v
        return None

    if t == "multiple_choice":
        if not isinstance(raw, list):
            return None
        out: list[str] = []
        for item in raw:
            s = str(item).strip()
            if s in option_values:
                out.append(s)
            else:
                for v in option_values:
                    if s.lower() == v.lower():
                        out.append(v)
                        break
        return out or None

    return None


# ──────────────────────────────────────────────────────────────────────────
# Orchestration
# ──────────────────────────────────────────────────────────────────────────

@dataclass
class RespondentResult:
    ok: bool
    error: str | None = None
    answers_written: int = 0


async def _run_one(
    *,
    db_factory,
    survey: Survey,
    questions: list[Question],
    persona: dict[str, Any],
    model: str,
) -> RespondentResult:
    system_prompt = build_system_prompt(persona)
    user_prompt = build_user_prompt(questions)
    try:
        raw = await llm.chat_json(model=model, system=system_prompt, user=user_prompt)
    except llm.LLMError as e:
        return RespondentResult(ok=False, error=str(e))

    try:
        parsed = _extract_json(raw)
    except json.JSONDecodeError as e:
        return RespondentResult(ok=False, error=f"JSON parse failed: {e} | raw[:200]={raw[:200]!r}")

    items = parsed.get("answers")
    if not isinstance(items, list):
        return RespondentResult(ok=False, error=f"No 'answers' array in model output: {parsed!r}")

    qmap = {q.id: q for q in questions}
    normalised: list[tuple[int, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        try:
            qid = int(item.get("question_id"))
        except (TypeError, ValueError):
            continue
        q = qmap.get(qid)
        if q is None:
            continue
        opt_values = {o.value for o in q.options}
        val = _normalize(q.type, opt_values, item.get("value"))
        if val is None:
            continue
        normalised.append((qid, val))

    if not normalised:
        return RespondentResult(ok=False, error="Model produced no valid answers")

    # Persist in its own session — concurrent respondents don't share sessions.
    async with db_factory() as db:
        resp = Response(
            survey_id=survey.id,
            user_id=None,
            anon_token=None,
            is_complete=True,
            submitted_at=datetime.now(timezone.utc),
            is_synthetic=True,
            synthetic_profile={**persona, "model": model},
        )
        db.add(resp)
        await db.flush()
        for qid, val in normalised:
            db.add(Answer(response_id=resp.id, question_id=qid, value={"value": val}))
        await db.commit()

    return RespondentResult(ok=True, answers_written=len(normalised))


async def run_batch(
    *,
    db_factory,
    survey: Survey,
    questions: list[Question],
    persona: dict[str, Any],
    model: str,
    count: int,
    concurrency: int,
) -> list[RespondentResult]:
    """Generate `count` synthetic respondents with bounded concurrency."""
    sem = asyncio.Semaphore(concurrency)

    async def _guarded() -> RespondentResult:
        async with sem:
            return await _run_one(
                db_factory=db_factory, survey=survey,
                questions=questions, persona=persona, model=model,
            )

    return await asyncio.gather(*[_guarded() for _ in range(count)])
