"""Pydantic schemas for the Settlement resource."""

import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field


class SettlementCreate(BaseModel):
    from_member: uuid.UUID  # who paid
    to_member: uuid.UUID  # who received
    amount_minor: int = Field(gt=0)
    note: str | None = Field(default=None, max_length=200)
    settled_at: date | None = None


class SettlementRead(BaseModel):
    id: uuid.UUID
    from_member: uuid.UUID
    from_name: str
    to_member: uuid.UUID
    to_name: str
    amount_minor: int
    note: str | None
    settled_at: date
    created_at: datetime
