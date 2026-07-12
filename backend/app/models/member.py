"""Member model.

A member is a person in a group. They MAY be a registered user (user_id set) or
a non-user placeholder added by name only (user_id null) — the locked "add
anyone" decision. When a placeholder later signs up and claims their spot, we
set user_id (Slice 3d).
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Member(Base):
    __tablename__ = "members"
    __table_args__ = (
        # A given user appears at most once per group. Non-user placeholders
        # (user_id NULL) are exempt — Postgres treats NULLs as distinct — so a
        # group can hold several unclaimed placeholders.
        UniqueConstraint("group_id", "user_id", name="uq_member_group_user"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)

    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"), index=True
    )
    # Nullable: null = a non-user placeholder. SET NULL on user delete keeps the
    # member (and their balances) around even if the account goes away.
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), index=True, nullable=True
    )

    # Display name — required for everyone (it's all a placeholder has).
    name: Mapped[str] = mapped_column(String(120))
    role: Mapped[str] = mapped_column(String(20), default="member")  # creator | member

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
