"""Server-side evaluator for question display conditions.

Rule shape:
    {"all": [<clause>, ...]}        -> AND
    {"any": [<clause>, ...]}        -> OR
    {"not": <rule>}                 -> negate
    <clause>: {"question_id": int, "op": str, "value": any}

Operators: eq, neq, gt, gte, lt, lte, in, not_in, contains, answered, not_answered.
Answer values follow the question schema and are normalized via _scalar().
"""
from typing import Any


def _scalar(answer: dict | None) -> Any:
    if answer is None:
        return None
    return answer.get("value", answer.get("text", answer))


def _matches(answer: dict | None, op: str, expected: Any) -> bool:
    val = _scalar(answer)
    if op == "answered":
        return answer is not None and val not in (None, "", [])
    if op == "not_answered":
        return answer is None or val in (None, "", [])
    if val is None:
        return False
    try:
        if op == "eq":
            return val == expected
        if op == "neq":
            return val != expected
        if op == "gt":
            return float(val) > float(expected)
        if op == "gte":
            return float(val) >= float(expected)
        if op == "lt":
            return float(val) < float(expected)
        if op == "lte":
            return float(val) <= float(expected)
        if op == "in":
            return val in (expected or [])
        if op == "not_in":
            return val not in (expected or [])
        if op == "contains":
            if isinstance(val, list):
                return expected in val
            return str(expected) in str(val)
    except (TypeError, ValueError):
        return False
    return False


def evaluate(rule: dict | None, answers_by_qid: dict[int, dict]) -> bool:
    if not rule:
        return True
    if "all" in rule:
        return all(evaluate(r, answers_by_qid) for r in rule["all"])
    if "any" in rule:
        return any(evaluate(r, answers_by_qid) for r in rule["any"])
    if "not" in rule:
        return not evaluate(rule["not"], answers_by_qid)
    qid = rule.get("question_id")
    op = rule.get("op", "eq")
    expected = rule.get("value")
    return _matches(answers_by_qid.get(qid), op, expected)
