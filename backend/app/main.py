"""FairShare API — application entry point.

Run locally with:  uv run uvicorn app.main:app --reload
Interactive docs:   http://localhost:8000/docs
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router

app = FastAPI(
    title="FairShare API",
    version="0.1.0",
    summary="Backend for the FairShare expense-splitting app.",
)

# CORS: let the Flutter web app (served from a different localhost port) call
# this API from the browser. Dev-only wildcard — tighten to real origins before
# production. We authenticate with bearer tokens (not cookies), so credentials
# stay off, which keeps the wildcard origin safe.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
