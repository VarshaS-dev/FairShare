"""Helpers for writing to the activity log.

`record_activity` just stages the row on the session — the caller's existing
`db.commit()` persists it in the same transaction as the action it describes.
"""

import uuid

from sqlalchemy.orm import Session

from app.models.activity import Activity
from app.models.user import User


def record_activity(
    db: Session,
    *,
    group_id: uuid.UUID,
    actor_id: uuid.UUID | None,
    type_: str,
    summary: str,
) -> None:
    db.add(
        Activity(
            group_id=group_id,
            actor_id=actor_id,
            type=type_,
            summary=summary,
        )
    )


def actor_name(user: User) -> str:
    return user.display_name or user.email or "Someone"


def fmt_amount(minor: int, currency: str) -> str:
    """Format integer minor units as e.g. 'INR 100.50'."""
    return f"{currency} {minor // 100}.{minor % 100:02d}"
