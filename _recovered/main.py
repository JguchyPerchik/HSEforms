import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .config import settings
from .core.rate_limit import limiter
from .database import engine
from . import models  # noqa: F401  (register models with metadata)
from .routers import auth, surveys, questions, responses, analytics, collaborators, uploads


async def _run_alembic_upgrade() -> None:
    """Apply pending migrations via subprocess (alembic command is sync)."""
    proc = await asyncio.create_subprocess_exec(
        "alembic", "upgrade", "head",
        cwd="/app",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
    )
    out, _ = await proc.communicate()
    if proc.returncode != 0:
        print(f"[alembic] migration failed:\n{out.decode(errors='replace')}")
        raise RuntimeError("Alembic upgrade failed — see logs")
    else:
        print("[alembic] upgrade head — OK")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _run_alembic_upgrade()
    yield
    await engine.dispose()


app = FastAPI(title="HSE Forms API", version="0.3.0", lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

origins = [o.strip() for o in settings.CORS_ORIGINS.split(",")] if settings.CORS_ORIGINS else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
