"""Expense endpoints (create / list / update / delete)."""

import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.expense import Expense, ExpenseSplit
from app.models.group import Group
from app.models.member import Member
from app.models.user import User
from app.schemas.expense import (
    ExpenseCreate,
    ExpenseRead,
    ExpenseSplitRead,
    SplitEntry,
)
from app.services.activity import actor_name, fmt_amount, record_activity

router = APIRouter(prefix="/groups", tags=["expenses"])


def _is_member(db: Session, group_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    return (
        db.scalar(
            select(Member.id).where(
                Member.group_id == group_id, Member.user_id == user_id
            )
        )
        is not None
    )


def _name_map(db: Session, group_id: uuid.UUID) -> dict[uuid.UUID, str]:
    rows = db.execute(
        select(Member, User)
        .outerjoin(User, User.id == Member.user_id)
        .where(Member.group_id == group_id)
    ).all()
    return {
        m.id: (u.display_name if (u is not None and u.display_name) else m.name)
        for m, u in rows
    }


def _equal_split(total: int, member_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    ordered = sorted(member_ids, key=str)
    base, remainder = divmod(total, len(ordered))
    return {mid: base + (1 if i < remainder else 0) for i, mid in enumerate(ordered)}


def _proportional_split(
    total: int, weights: dict[uuid.UUID, int]
) -> dict[uuid.UUID, int]:
    """Largest-remainder split so shares always sum to EXACTLY `total`."""
    total_weight = sum(weights.values())
    floors: dict[uuid.UUID, int] = {}
    remainders: list[tuple[int, str, uuid.UUID]] = []
    allocated = 0
    for mid, w in weights.items():
        share = (total * w) // total_weight
        floors[mid] = share
        allocated += share
        remainders.append(((total * w) % total_weight, str(mid), mid))
    leftover = total - allocated
    remainders.sort(key=lambda r: (-r[0], r[1]))
    result = dict(floors)
    for i in range(leftover):
        result[remainders[i][2]] += 1
    return result


def _compute_shares(
    method: str, total: int, entries: list[SplitEntry]
) -> dict[uuid.UUID, int]:
    if method == "equal":
        return _equal_split(total, [e.member_id for e in entries])

    values = {e.member_id: (e.value or 0) for e in entries}
    if any(v < 0 for v in values.values()):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Values can't be negative.")

    if method == "exact":
        if sum(values.values()) != total:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "The exact amounts must add up to the total.",
            )
        return values
    if method == "percentage":
        if sum(values.values()) != 100:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "Percentages must add up to 100."
            )
        return _proportional_split(total, values)
    if method == "shares":
        if sum(values.values()) <= 0:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Shares must be positive.")
        return _proportional_split(total, values)

    raise HTTPException(status.HTTP_400_BAD_REQUEST, "Unknown split method.")


def _prepare_shares(
    db: Session, group_id: uuid.UUID, payload: ExpenseCreate
) -> dict[uuid.UUID, int]:
    """Validate the payer/participants against the group, then compute shares."""
    member_ids = {
        m for m in db.scalars(select(Member.id).where(Member.group_id == group_id))
    }
    if payload.paid_by not in member_ids:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "The payer isn't in this group.")

    seen: set[uuid.UUID] = set()
    for e in payload.split.entries:
        if e.member_id not in member_ids:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "A participant isn't in this group."
            )
        if e.member_id in seen:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "A participant is listed twice."
            )
        seen.add(e.member_id)

    return _compute_shares(payload.split.method, payload.amount_minor, payload.split.entries)


def _to_read(
    expense: Expense,
    splits: list[ExpenseSplit],
    names: dict[uuid.UUID, str],
) -> ExpenseRead:
    return ExpenseRead(
        id=expense.id,
        description=expense.description,
        amount_minor=expense.amount_minor,
        paid_by=expense.paid_by,
        paid_by_name=names.get(expense.paid_by, "Unknown"),
        category=expense.category,
        spent_at=expense.spent_at,
        created_at=expense.created_at,
        splits=[
            ExpenseSplitRead(member_id=s.member_id, share_minor=s.share_minor)
            for s in splits
        ],
    )


def _load_expense(db: Session, group_id: uuid.UUID, expense_id: uuid.UUID) -> Expense:
    expense = db.get(Expense, expense_id)
    if (
        expense is None
        or expense.group_id != group_id
        or expense.deleted_at is not None
    ):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Expense not found")
    return expense


@router.post(
    "/{group_id}/expenses",
    response_model=ExpenseRead,
    status_code=status.HTTP_201_CREATED,
)
def create_expense(
    group_id: uuid.UUID,
    payload: ExpenseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ExpenseRead:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    shares = _prepare_shares(db, group_id, payload)

    expense = Expense(
        group_id=group_id,
        description=payload.description.strip(),
        amount_minor=payload.amount_minor,
        paid_by=payload.paid_by,
        category=payload.category,
        spent_at=payload.spent_at or date.today(),
        created_by=current_user.id,
    )
    db.add(expense)
    db.flush()

    split_objs = [
        ExpenseSplit(expense_id=expense.id, member_id=mid, share_minor=amt)
        for mid, amt in shares.items()
    ]
    db.add_all(split_objs)

    currency = db.scalar(select(Group.currency).where(Group.id == group_id)) or ""
    record_activity(
        db,
        group_id=group_id,
        actor_id=current_user.id,
        type_="expense_added",
        summary=f'{actor_name(current_user)} added "{expense.description}" '
        f"({fmt_amount(expense.amount_minor, currency)})",
    )
    db.commit()
    db.refresh(expense)
    return _to_read(expense, split_objs, _name_map(db, group_id))


@router.put("/{group_id}/expenses/{expense_id}", response_model=ExpenseRead)
def update_expense(
    group_id: uuid.UUID,
    expense_id: uuid.UUID,
    payload: ExpenseCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ExpenseRead:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")
    expense = _load_expense(db, group_id, expense_id)

    shares = _prepare_shares(db, group_id, payload)

    expense.description = payload.description.strip()
    expense.amount_minor = payload.amount_minor
    expense.paid_by = payload.paid_by
    expense.category = payload.category
    if payload.spent_at is not None:
        expense.spent_at = payload.spent_at

    # Replace the splits wholesale — simplest correct way to re-split.
    db.execute(delete(ExpenseSplit).where(ExpenseSplit.expense_id == expense.id))
    split_objs = [
        ExpenseSplit(expense_id=expense.id, member_id=mid, share_minor=amt)
        for mid, amt in shares.items()
    ]
    db.add_all(split_objs)
    record_activity(
        db,
        group_id=group_id,
        actor_id=current_user.id,
        type_="expense_updated",
        summary=f'{actor_name(current_user)} updated "{expense.description}"',
    )
    db.commit()
    db.refresh(expense)
    return _to_read(expense, split_objs, _name_map(db, group_id))


@router.delete(
    "/{group_id}/expenses/{expense_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_expense(
    group_id: uuid.UUID,
    expense_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")
    expense = _load_expense(db, group_id, expense_id)
    # Soft delete: keep the row (and its splits) for history/audit.
    expense.deleted_at = datetime.now(timezone.utc)
    record_activity(
        db,
        group_id=group_id,
        actor_id=current_user.id,
        type_="expense_deleted",
        summary=f'{actor_name(current_user)} deleted "{expense.description}"',
    )
    db.commit()


@router.get("/{group_id}/expenses", response_model=list[ExpenseRead])
def list_expenses(
    group_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ExpenseRead]:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    expenses = list(
        db.scalars(
            select(Expense)
            .where(Expense.group_id == group_id, Expense.deleted_at.is_(None))
            .order_by(Expense.spent_at.desc(), Expense.created_at.desc())
        )
    )
    names = _name_map(db, group_id)
    result: list[ExpenseRead] = []
    for e in expenses:
        splits = list(
            db.scalars(select(ExpenseSplit).where(ExpenseSplit.expense_id == e.id))
        )
        result.append(_to_read(e, splits, names))
    return result
