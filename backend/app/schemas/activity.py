"""Pydantic schema for the Activity feed."""

import uuid
from datetime import datetime

from pydantic import BaseModel


class ActivityRead(BaseModel):
    id: uuid.UUID
    group_id: uuid.UUID
    group_name: str
    type: str
    summary: str
    actor_name: str | None
    created_at: datetime
