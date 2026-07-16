"""Balances endpoint — net position per member + simplified settlements.

Everything here is DERIVED from expenses; there are no balance tables. Net
balances always sum to zero, which is what lets the simplification terminate.
"""

import uuid
from collections import defaultdict

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.expense import Expense, ExpenseSplit
from app.models.group import Group
from app.models.member import Member
from app.models.settlement import Settlement
from app.models.user import User
from app.schemas.balance import BalancesRead, MemberBalance, SuggestedPayment

router = APIRouter(prefix="/groups", tags=["balances"])


def _is_member(db: Session, group_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    return (
        db.scalar(
            select(Member.id).where(
                Member.group_id == group_id, Member.user_id == user_id
            )
        )
        is not None
    )


def _simplify(
    net: dict[uuid.UUID, int],
) -> list[tuple[uuid.UUID, uuid.UUID, int]]:
    """Greedy min-cash-flow: match the biggest debtor with the biggest creditor,
    settle the smaller of the two, repeat. Produces at most n-1 transfers."""
    debtors = sorted(
        ([mid, -amt] for mid, amt in net.items() if amt < 0),
        key=lambda x: -x[1],
    )
    creditors = sorted(
        ([mid, amt] for mid, amt in net.items() if amt > 0),
        key=lambda x: -x[1],
    )

    transfers: list[tuple[uuid.UUID, uuid.UUID, int]] = []
    i = j = 0
    while i < len(debtors) and j < len(creditors):
        pay = min(debtors[i][1], creditors[j][1])
        transfers.append((debtors[i][0], creditors[j][0], pay))
        debtors[i][1] -= pay
        creditors[j][1] -= pay
        if debtors[i][1] == 0:
            i += 1
        if creditors[j][1] == 0:
            j += 1
    return transfers


@router.get("/{group_id}/balances", response_model=BalancesRead)
def get_balances(
    group_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> BalancesRead:
    group = db.get(Group, group_id)
    if group is None or not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    rows = db.execute(
        select(Member, User)
        .outerjoin(User, User.id == Member.user_id)
        .where(Member.group_id == group_id)
    ).all()
    members = [m for m, _ in rows]
    names = {
        m.id: (u.display_name if (u is not None and u.display_name) else m.name)
        for m, u in rows
    }
    me_member_id = next((m.id for m, _ in rows if m.user_id == current_user.id), None)

    expenses = list(
        db.scalars(
            select(Expense).where(
                Expense.group_id == group_id, Expense.deleted_at.is_(None)
            )
        )
    )
    paid: dict[uuid.UUID, int] = defaultdict(int)
    for e in expenses:
        paid[e.paid_by] += e.amount_minor

    owed: dict[uuid.UUID, int] = defaultdict(int)
    expense_ids = [e.id for e in expenses]
    if expense_ids:
        splits = db.scalars(
            select(ExpenseSplit).where(ExpenseSplit.expense_id.in_(expense_ids))
        )
        for s in splits:
            owed[s.member_id] += s.share_minor

    # Settlements (recorded payments) move both parties toward zero: the payer's
    # debt shrinks, the receiver's credit shrinks.
    settle_out: dict[uuid.UUID, int] = defaultdict(int)
    settle_in: dict[uuid.UUID, int] = defaultdict(int)
    for s in db.scalars(
        select(Settlement).where(
            Settlement.group_id == group_id, Settlement.deleted_at.is_(None)
        )
    ):
        settle_out[s.from_member] += s.amount_minor
        settle_in[s.to_member] += s.amount_minor

    net = {
        m.id: (paid[m.id] - owed[m.id]) + (settle_out[m.id] - settle_in[m.id])
        for m in members
    }

    balances = [
        MemberBalance(member_id=m.id, name=names[m.id], net_minor=net[m.id])
        for m in members
    ]
    balances.sort(key=lambda b: -b.net_minor)  # owed-most first

    settlements = [
        SuggestedPayment(
            from_member_id=d,
            from_name=names.get(d, "?"),
            to_member_id=c,
            to_name=names.get(c, "?"),
            amount_minor=amt,
        )
        for d, c, amt in _simplify(net)
    ]

    return BalancesRead(
        currency=group.currency,
        me_member_id=me_member_id,
        balances=balances,
        settlements=settlements,
    )
