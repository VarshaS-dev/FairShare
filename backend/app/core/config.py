"""Application configuration, loaded from environment variables / .env.

pydantic-settings validates and types these on startup, so a missing or
malformed value fails fast and loudly instead of surfacing as a mystery bug
later. Never hardcode secrets in code — they come from the environment.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Postgres. Uses the psycopg (v3) driver via the +psycopg suffix.
    database_url: str = (
        "postgresql+psycopg://fairshare:fairshare_dev_pw@localhost:5432/fairshare"
    )

    # Firebase project that issues the ID tokens we verify (see Slice 2c).
    firebase_project_id: str = "fairshare-3f1b1"

    # Path to the Firebase Admin service-account JSON file (local dev).
    google_application_credentials: str | None = None

    # The service-account JSON *content*, for cloud hosts that inject secrets as
    # env vars rather than files. Takes precedence over the file path if set.
    firebase_service_account_json: str | None = None

    # Comma-separated allowed CORS origins ("*" = any). Only the browser web
    # build needs this; native apps ignore CORS. Tighten in production.
    cors_origins: str = "*"


settings = Settings()
