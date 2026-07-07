"""Pydantic schemas for the Group resource."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class GroupCreate(BaseModel):
    """Request body for creating a group."""

    name: str = Field(min_length=1, max_length=80)
    currency: str = Field(default="INR", min_length=3, max_length=3)


class GroupRead(BaseModel):
    """Group as returned by the API."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    currency: str
    created_at: datetime
