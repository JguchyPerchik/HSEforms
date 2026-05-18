from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..database import get_db
from ..models import User
from .security import decode_token


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Пожалуйста, войдите в систему, чтобы продолжить.")
    token = authorization.split(" ", 1)[1].strip()
    payload = decode_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Ваша рабочая сессия устарела или недействительна. Пожалуйста, авторизуйтесь заново.")
    user = await db.get(User, int(payload["sub"]))
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Аккаунт не найден. Возможно, ваш профиль был удален.")
    return user


async def get_optional_user(
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
) -> User | None:
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    token = authorization.split(" ", 1)[1].strip()
    payload = decode_token(token)
    if not payload or "sub" not in payload:
        return None
    return await db.get(User, int(payload["sub"]))
