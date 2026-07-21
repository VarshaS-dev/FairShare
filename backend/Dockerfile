# FairShare API container.
# Build context is backend/. Migrations run on start, then uvicorn serves.

FROM python:3.12-slim

# uv: fast, reproducible dependency installs (copied from the official image).
COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

WORKDIR /app

# Install locked dependencies into /app/.venv.
COPY . .
RUN uv sync --frozen --no-dev

# Put the venv on PATH so `alembic` / `uvicorn` resolve.
ENV PATH="/app/.venv/bin:$PATH"

# Most hosts (Render, etc.) inject the port to listen on via $PORT.
ENV PORT=8000
EXPOSE 8000

# Apply DB migrations, then serve. Shell form so $PORT expands and && chains.
CMD alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
