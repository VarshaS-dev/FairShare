"""Expense + ExpenseSplit models.

An expense = one person paid a total, and that total is split across a set of
participants. All money is stored as INTEGER minor units (paise/cents) — never
floats — so splits always sum exactly to the total (the Phase-1 money rule).

`paid_by` and split `member_id` reference MEMBERS, not users — because a non-user
placeholder can pay for or share in an expense too.
"""

import uuid
from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    DateTime,
    ForeignKey,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Expense(Base):
    __tablename__ = "expenses"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    group_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("groups.id", ondelete="CASCADE"), index=True
    )
    description: Mapped[str] = mapped_column(String(200))

    # Total, in the group's currency minor units (e.g. paise). Integer only.
    amount_minor: Mapped[int] = mapped_column(BigInteger)

    # The member who paid (RESTRICT: you can't delete a member who paid).
    paid_by: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("members.id", ondelete="RESTRICT"), index=True
    )

    category: Mapped[str | None] = mapped_column(String(40))
    spent_at: Mapped[date] = mapped_column(Date)

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    # Soft delete: keep the row so history/audit stays intact.
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class ExpenseSplit(Base):
    __tablename__ = "expense_splits"
    __table_args__ = (
        UniqueConstraint("expense_id", "member_id", name="uq_split_expense_member"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    expense_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("expenses.id", ondelete="CASCADE"), index=True
    )
    member_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("members.id", ondelete="RESTRICT"), index=True
    )
    # What THIS member owes for this expense, in minor units.
    share_minor: Mapped[int] = mapped_column(BigInteger)
