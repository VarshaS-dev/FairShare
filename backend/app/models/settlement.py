"""A settlement records a real-world payment from one member to another.

Track-only (our Phase-1 decision): we don't move money, we just record that it
happened. In the balance math it shifts both people toward zero — the payer's
debt shrinks, the receiver's credit shrinks.
"""

import uuid
from datetime import date, datetime

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Settlement(Base):
    __tablename__ = "settlements"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"), index=True
    )
    from_member: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("members.id", ondelete="RESTRICT"), index=True
    )
    to_member: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("members.id", ondelete="RESTRICT"), index=True
    )
    amount_minor: Mapped[int] = mapped_column(BigInteger)
    note: Mapped[str | None] = mapped_column(String(200))
    settled_at: Mapped[date] = mapped_column(Date)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
