"""FairShare API — application entry point.

Run locally with:  uv run uvicorn app.main:app --reload
Interactive docs:   http://localhost:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings

app = FastAPI(
    title="FairShare API",
    version="0.1.0",
    summary="Backend for the FairShare expense-splitting app.",
)

# CORS: only the browser web build needs this (native apps ignore it). Origins
# come from settings — "*" in dev, a real allowlist in production. We use bearer
# tokens (not cookies), so credentials stay off.
_origins = (
    ["*"]
    if settings.cors_origins.strip() == "*"
    else [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health", tags=["system"])
def health() -> dict[str, str]:
    """Liveness probe — confirms the API process is up and serving."""
    return {"status": "ok"}


@app.get("/", tags=["system"])
def root() -> dict[str, str]:
    return {"service": "FairShare API", "docs": "/docs"}
