from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text

from .config import settings
from .database import Base, engine
from . import models  # noqa: F401  (register models with metadata)
from .routers import auth, surveys, questions, responses, analytics, collaborators, uploads


# Lightweight, idempotent migrations applied on every startup.
# Postgres-only DDL — uses IF NOT EXISTS to stay safe across reruns.
_MIGRATIONS_SQL = [
    "ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'time'",
    "ALTER TYPE question_type ADD VALUE IF NOT EXISTS 'file_upload'",
    "ALTER TABLE questions ADD COLUMN IF NOT EXISTS media_url VARCHAR(2000) NULL",
    "ALTER TABLE question_options ADD COLUMN IF NOT EXISTS media_url VARCHAR(2000) NULL",
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    # Enum-value additions cannot run inside a transaction block, so use AUTOCOMMIT.
    autocommit_engine = engine.execution_options(isolation_level="AUTOCOMMIT")
    async with autocommit_engine.connect() as conn:
        for stmt in _MIGRATIONS_SQL:
            try:
                await conn.execute(text(stmt))
            except Exception as e:  # noqa: BLE001
                # Don't crash the app if a migration is already applied or
                # against a non-Postgres DB during dev.
                print(f"[migrations] skipped: {stmt} ({e!r})")
    yield
    await engine.dispose()


app = FastAPI(title="HSE Forms API", version="0.2.0", lifespan=lifespan)

origins = [o.strip() for o in settings.CORS_ORIGINS.split(",")] if settings.CORS_ORIGINS else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static media — served back at /uploads/<filename>.
upload_dir = Path("/data/uploads")
upload_dir.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(upload_dir)), name="uploads")

app.include_router(auth.router)
app.include_router(surveys.router)
app.include_router(questions.router)
app.include_router(responses.router)
app.include_router(analytics.router)
app.include_router(collaborators.router)
app.include_router(uploads.router)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
