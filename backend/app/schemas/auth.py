from pydantic import BaseModel, EmailStr


class RegisterIn(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class TelegramAuthIn(BaseModel):
    init_data: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: int
    email: str | None = None
    full_name: str | None = None
    telegram_id: int | None = None
    telegram_username: str | None = None

    class Config:
        from_attributes = True
