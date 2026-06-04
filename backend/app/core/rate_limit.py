"""Shared SlowAPI limiter — Redis-backed, IP-keyed.

Важно: rate-limit считается per-IP. За reverse-proxy (Caddy/nginx) дефолтный
`get_remote_address` из slowapi вернёт внутренний IP прокси-контейнера —
а это значит, что все респонденты разделят один общий bucket, и первые
N запросов в минуту "съедят" лимит за всех. Поэтому используем кастомный
key_func, который сначала смотрит в X-Forwarded-For (его проставляет Caddy
через reverse_proxy), и только если его нет — падает обратно на client.host.
"""
from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..config import settings


def _client_ip(request: Request) -> str:
    # X-Forwarded-For может быть цепочкой "real, proxy1, proxy2" — берём первый,
    # это исходный клиент. Caddy подставляет именно реальный адрес.
    xff = request.headers.get("x-forwarded-for")
    if xff:
        first = xff.split(",")[0].strip()
        if first:
            return first
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    return get_remote_address(request)


limiter = Limiter(
    key_func=_client_ip,
    storage_uri=settings.REDIS_URL,
    default_limits=["200/minute"],
    strategy="fixed-window",
)
