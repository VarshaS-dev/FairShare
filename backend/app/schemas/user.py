"""Pydantic schemas for the User resource (API request/response shapes)."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserRead(BaseModel):
    # from_attributes lets FastAPI build this straight from a SQLAlchemy model.
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str | None
    display_name: str | None
    created_at: datetime
