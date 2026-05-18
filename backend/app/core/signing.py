"""HMAC-signed media URLs.

We don't want raw `/uploads/<uuid>.<ext>` to be world-readable. The DB stores
the bare path; whenever we serialise a Question/Option/Answer for the client,
we wrap each `media_url` with a signature + expiration query string.

The serving endpoint validates the signature before returning the file.

Signing key: `JWT_SECRET + "::uploads"` — domain-separated from JWT.
"""
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer

from ..config import settings


_DEFAULT_TTL = 60 * 60 * 24 * 7  # 7 days


def _serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(
        secret_key=settings.JWT_SECRET + "::uploads",
        salt="hse-forms-uploads",
    )


def sign_path(path: str, ttl_seconds: int = _DEFAULT_TTL) -> str:
    """Return a signed URL with `?sig=...` appended.

    `path` is the bare relative URL stored in DB, e.g. `/uploads/abc.png`.
    """
    if not path or not path.startswith("/uploads/"):
        return path
    sig = _serializer().dumps(path)
    sep = "&" if "?" in path else "?"
    return f"{path}{sep}sig={sig}"


def verify_signature(path: str, sig: str | None, max_age_seconds: int = _DEFAULT_TTL) -> bool:
    if not sig:
        return False
    try:
        decoded = _serializer().loads(sig, max_age=max_age_seconds)
    except SignatureExpired:
        return False
    except BadSignature:
        return False
    return decoded == path
