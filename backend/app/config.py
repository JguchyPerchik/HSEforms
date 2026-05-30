from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "postgresql+asyncpg://hse:hse@db:5432/hse_forms"
    REDIS_URL: str = "redis://redis:6379/0"
    JWT_SECRET: str = "change-me"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 24 * 7
    TELEGRAM_BOT_TOKEN: str = ""
    CORS_ORIGINS: str = "*"

    # LLM provider for synthetic respondents.
    # "groq"       — fast, generous free tier (30 RPM, 14400 RPD), recommended
    # "openrouter" — gateway to many models, including free + paid
    LLM_PROVIDER: str = "groq"
    LLM_DEFAULT_MODEL: str = "llama-3.3-70b-versatile"  # Groq's default

    # Per-provider keys (only the matching one needs to be set).
    GROQ_API_KEY: str = ""
    OPENROUTER_API_KEY: str = ""

    SYNTHETIC_MAX_PER_REQUEST: int = 50
    # Groq free tier: 30 req/min — concurrency 3 безопасно.
    # OpenRouter free tier: ~1 req/20s per provider — лучше 1.
    SYNTHETIC_CONCURRENCY: int = 3


settings = Settings()
