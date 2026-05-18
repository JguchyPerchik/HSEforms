"""Shared SlowAPI limiter — Redis-backed, IP-keyed."""
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..config import settings


limiter = Limiter(
    key_func=get_remote_address,
    storage_uri=settings.REDIS_URL,
    default_limits=["200/minute"],
    strategy="fixed-window",
)
