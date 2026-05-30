"""Provider-agnostic LLM client for synthetic respondents.

Both Groq and OpenRouter expose the OpenAI-compatible /chat/completions schema,
so this module just dispatches by `settings.LLM_PROVIDER` and reuses one
request flow (with retry-on-429 honoring upstream Retry-After).

Switch providers via env: `LLM_PROVIDER=groq` or `LLM_PROVIDER=openrouter`.
"""
from __future__ import annotations

import asyncio
import json

import httpx

from ..config import settings


_PROVIDERS: dict[str, dict[str, str]] = {
    "groq": {
        "url": "https://api.groq.com/openai/v1/chat/completions",
        "key_attr": "GROQ_API_KEY",
        "label": "Groq",
    },
    "openrouter": {
        "url": "https://openrouter.ai/api/v1/chat/completions",
        "key_attr": "OPENROUTER_API_KEY",
        "label": "OpenRouter",
    },
}

_MAX_RETRIES = 3
_MAX_BACKOFF_SECONDS = 60.0


class LLMError(RuntimeError):
    pass


# Backwards-compat alias so existing imports keep working.
OpenRouterError = LLMError


def _provider_config() -> dict[str, str]:
    p = settings.LLM_PROVIDER.lower()
    cfg = _PROVIDERS.get(p)
    if not cfg:
        raise LLMError(f"Unknown LLM_PROVIDER={p!r}. Supported: {list(_PROVIDERS)}")
    api_key = getattr(settings, cfg["key_attr"], "") or ""
    if not api_key:
        raise LLMError(
            f"{cfg['label']} selected but {cfg['key_attr']} is not configured. "
            f"Set it in .env / docker-compose."
        )
    return {**cfg, "api_key": api_key}


def _extract_retry_after(response: httpx.Response) -> float:
    """Pull seconds-to-wait from headers (both providers) or body (OpenRouter)."""
    header = response.headers.get("Retry-After") or response.headers.get("retry-after")
    if header:
        try:
            return float(header)
        except ValueError:
            pass
    try:
        body = response.json()
        meta = (body.get("error") or {}).get("metadata") or {}
        v = meta.get("retry_after_seconds") or meta.get("retry_after_seconds_raw")
        if v is not None:
            return float(v)
    except (json.JSONDecodeError, ValueError, AttributeError):
        pass
    return 5.0


async def chat_json(
    *,
    model: str,
    system: str,
    user: str,
    temperature: float = 0.8,
    timeout: float = 90.0,
) -> str:
    """Call current provider's chat/completions and return assistant message text.

    Forces JSON output via `response_format` (supported by both Groq and most
    OpenRouter models). Retries up to _MAX_RETRIES on HTTP 429.
    """
    cfg = _provider_config()

    headers = {
        "Authorization": f"Bearer {cfg['api_key']}",
        "Content-Type": "application/json",
    }
    # OpenRouter looks at these for analytics/landing — harmless for Groq.
    if cfg["label"] == "OpenRouter":
        headers["HTTP-Referer"] = "https://hse-forms.local"
        headers["X-Title"] = "HSE Forms Synthetic Respondents"

    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "temperature": temperature,
        "response_format": {"type": "json_object"},
    }

    async with httpx.AsyncClient(timeout=timeout) as client:
        last_429_text: str | None = None
        for attempt in range(_MAX_RETRIES + 1):
            r = await client.post(cfg["url"], headers=headers, json=body)
            if r.status_code == 429 and attempt < _MAX_RETRIES:
                wait_s = min(_extract_retry_after(r), _MAX_BACKOFF_SECONDS)
                last_429_text = r.text[:300]
                await asyncio.sleep(wait_s + 0.5)
                continue
            if r.status_code >= 400:
                raise LLMError(
                    f"{cfg['label']} HTTP {r.status_code}: {r.text[:500]}"
                )
            data = r.json()
            try:
                return data["choices"][0]["message"]["content"]
            except (KeyError, IndexError) as e:
                raise LLMError(f"Unexpected {cfg['label']} response: {data}") from e

        raise LLMError(
            f"{cfg['label']} rate-limited after {_MAX_RETRIES} retries: {last_429_text}"
        )
