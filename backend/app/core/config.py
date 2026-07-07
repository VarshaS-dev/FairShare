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

    # Path to the Firebase Admin service-account JSON (set in .env in Slice 2c).
    google_application_credentials: str | None = None


settings = Settings()
