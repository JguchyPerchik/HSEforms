from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..models import User
from ..schemas.auth import LoginIn, RegisterIn, TelegramAuthIn, TokenOut, UserOut
from ..core.security import create_access_token, hash_password, verify_password
from ..core.telegram import parse_init_data
from ..core.deps import get_current_user
from ..core.rate_limit import limiter


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenOut)
@limiter.limit("5/minute")
async def register(
    request: Request,
    data: RegisterIn,
    db: AsyncSession = Depends(get_db),
) -> TokenOut:
    existing = await db.execute(select(User).where(User.email == data.email))
    if existing.scalar_one_or_none():
        raise HTTPException(status.HTTP_409_CONFLICT, "Email уже зарегистрирован")
    user = User(
        email=data.email,
        password_hash=hash_password(data.password),
        full_name=data.full_name,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return TokenOut(access_token=create_access_token(user.id))


@router.post("/login", response_model=TokenOut)
@limiter.limit("10/minute")
async def login(
    request: Request,
    data: LoginIn,
    db: AsyncSession = Depends(get_db),
) -> TokenOut:
    res = await db.execute(select(User).where(User.email == data.email))
    user = res.scalar_one_or_none()
    if not user or not user.password_hash or not verify_password(data.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Неверный email или пароль.")
    return TokenOut(access_token=create_access_token(user.id))


@router.post("/telegram", response_model=TokenOut)
@limiter.limit("30/minute")
async def telegram_auth(
    request: Request,
    data: TelegramAuthIn,
    db: AsyncSession = Depends(get_db),
) -> TokenOut:
    parsed = parse_init_data(data.init_data)
    if not parsed:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Не удалось безопасно войти через Telegram. Похоже, сессия устарела. Попробуйте перезапустить приложение.")
    tg_user = parsed.get("user") or {}
    tg_id = tg_user.get("id")
    if not tg_id:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Telegram не передал данные вашего профиля. Проверьте настройки конфиденциальности в мессенджере.")
    res = await db.execute(select(User).where(User.telegram_id == tg_id))
    user = res.scalar_one_or_none()
    if not user:
        user = User(
            telegram_id=tg_id,
            telegram_username=tg_user.get("username"),
            full_name=" ".join(filter(None, [tg_user.get("first_name"), tg_user.get("last_name")])) or None,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return TokenOut(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
async def me(user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(user)
