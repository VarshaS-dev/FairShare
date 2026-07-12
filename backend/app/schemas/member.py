"""Pydantic schemas for the Member resource."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, model_validator


class MemberCreate(BaseModel):
    """Add a member to a group. Provide EXACTLY ONE of:

    * ``name``  -> a non-user placeholder (they don't need an account)
    * ``email`` -> link an existing FairShare user
    """

    name: str | None = Field(default=None, min_length=1, max_length=120)
    email: str | None = Field(default=None, max_length=320)

    @model_validator(mode="after")
    def _exactly_one(self) -> "MemberCreate":
        # bool(name) == bool(email) catches both "neither" and "both".
        if bool(self.name) == bool(self.email):
            raise ValueError("Provide exactly one of `name` or `email`.")
        return self


class MemberRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    role: str
    user_id: uuid.UUID | None  # null = a non-user placeholder
    created_at: datetime
