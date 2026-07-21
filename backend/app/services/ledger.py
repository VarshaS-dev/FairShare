"""Shared balance math over a group's expenses + settlements.

The single source of truth for our money conventions, used by BOTH the group
balances endpoint (net per member) and the cross-group overview (pairwise).
Positive means money is owed TO that member; negative means they owe.
"""

import uuid
from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.expense import Expense, ExpenseSplit
from app.models.member import Member
from app.models.settlement import Settlement


def _active_expenses(db: Session, group_id: uuid.UUID) -> list[Expense]:
    return list(
        db.scalars(
            select(Expense).where(
                Expense.group_id == group_id, Expense.deleted_at.is_(None)
            )
        )
    )


def _splits_by_expense(
    db: Session, expense_ids: list[uuid.UUID]
) -> dict[uuid.UUID, list[ExpenseSplit]]:
    out: dict[uuid.UUID, list[ExpenseSplit]] = defaultdict(list)
    if expense_ids:
        for s in db.scalars(
            select(ExpenseSplit).where(ExpenseSplit.expense_id.in_(expense_ids))
        ):
            out[s.expense_id].append(s)
    return out


def _active_settlements(db: Session, group_id: uuid.UUID) -> list[Settlement]:
    return list(
        db.scalars(
            select(Settlement).where(
                Settlement.group_id == group_id, Settlement.deleted_at.is_(None)
            )
        )
    )


def compute_net(db: Session, group_id: uuid.UUID) -> dict[uuid.UUID, int]:
    """Net position per member: (paid − owed) + (settled_out − settled_in)."""
    expenses = _active_expenses(db, group_id)
    paid: dict[uuid.UUID, int] = defaultdict(int)
    owed: dict[uuid.UUID, int] = defaultdict(int)

    for e in expenses:
        paid[e.paid_by] += e.amount_minor
    for splits in _splits_by_expense(db, [e.id for e in expenses]).values():
        for s in splits:
            owed[s.member_id] += s.share_minor

    # A payment reduces the payer's debt and the receiver's credit — fold it
    # straight into `paid` so net stays `paid − owed`.
    for st in _active_settlements(db, group_id):
        paid[st.from_member] += st.amount_minor
        paid[st.to_member] -= st.amount_minor

    member_ids = list(
        db.scalars(select(Member.id).where(Member.group_id == group_id))
    )
    return {m: paid[m] - owed[m] for m in member_ids}


def compute_pairwise(
    db: Session, group_id: uuid.UUID, me_member_id: uuid.UUID
) -> dict[uuid.UUID, int]:
    """Pairwise balance between `me_member_id` and every other member.

    +value => the other member owes me; -value => I owe them. Only expenses one
    of us paid create a direct debt between us; third-party expenses don't.
    """
    pair: dict[uuid.UUID, int] = defaultdict(int)

    expenses = _active_expenses(db, group_id)
    splits = _splits_by_expense(db, [e.id for e in expenses])
    for e in expenses:
        shares = {s.member_id: s.share_minor for s in splits[e.id]}
        if e.paid_by == me_member_id:
            for mid, share in shares.items():
                if mid != me_member_id:
                    pair[mid] += share  # they owe me their share
        else:
            my_share = shares.get(me_member_id)
            if my_share:
                pair[e.paid_by] -= my_share  # I owe the payer my share

    for st in _active_settlements(db, group_id):
        if st.from_member == me_member_id:
            pair[st.to_member] += st.amount_minor
        elif st.to_member == me_member_id:
            pair[st.from_member] -= st.amount_minor

    return dict(pair)
