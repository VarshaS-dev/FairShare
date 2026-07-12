"""Pydantic schemas for invites."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class InviteCreate(BaseModel):
    # Set to make this a placeholder-claim invite; omit for a generic group join.
    member_id: uuid.UUID | None = None


class InviteRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    group_id: uuid.UUID
    member_id: uuid.UUID | None
    expires_at: datetime | None


class InvitePreview(BaseModel):
    """Shown before accepting, so the user knows what they're joining."""

    group_name: str
    currency: str
    claim_name: str | None  # name of the placeholder being claimed, if any
    already_member: bool
