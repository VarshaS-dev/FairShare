"""Settlement endpoints — record / list / undo a payment between members."""

import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.group import Group
from app.models.member import Member
from app.models.settlement import Settlement
from app.models.user import User
from app.schemas.settlement import SettlementCreate, SettlementRead
from app.services.activity import actor_name, fmt_amount, record_activity

router = APIRouter(prefix="/groups", tags=["settlements"])


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


def _to_read(s: Settlement, names: dict[uuid.UUID, str]) -> SettlementRead:
    return SettlementRead(
        id=s.id,
        from_member=s.from_member,
        from_name=names.get(s.from_member, "?"),
        to_member=s.to_member,
        to_name=names.get(s.to_member, "?"),
        amount_minor=s.amount_minor,
        note=s.note,
        settled_at=s.settled_at,
        created_at=s.created_at,
    )


@router.post(
    "/{group_id}/settlements",
    response_model=SettlementRead,
    status_code=status.HTTP_201_CREATED,
)
def record_settlement(
    group_id: uuid.UUID,
    payload: SettlementCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SettlementRead:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    if payload.from_member == payload.to_member:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "A payment needs two different people."
        )
    member_ids = {
        m for m in db.scalars(select(Member.id).where(Member.group_id == group_id))
    }
    if payload.from_member not in member_ids or payload.to_member not in member_ids:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "Both people must be in this group."
        )

    settlement = Settlement(
        group_id=group_id,
        from_member=payload.from_member,
        to_member=payload.to_member,
        amount_minor=payload.amount_minor,
        note=payload.note,
        settled_at=payload.settled_at or date.today(),
        created_by=current_user.id,
    )
    db.add(settlement)

    names = _name_map(db, group_id)
    currency = db.scalar(select(Group.currency).where(Group.id == group_id)) or ""
    record_activity(
        db,
        group_id=group_id,
        actor_id=current_user.id,
        type_="settlement_recorded",
        summary=f"{actor_name(current_user)} recorded a payment: "
        f"{names.get(settlement.from_member, '?')} → "
        f"{names.get(settlement.to_member, '?')} "
        f"({fmt_amount(settlement.amount_minor, currency)})",
    )
    db.commit()
    db.refresh(settlement)
    return _to_read(settlement, names)


@router.get("/{group_id}/settlements", response_model=list[SettlementRead])
def list_settlements(
    group_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[SettlementRead]:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    settlements = list(
        db.scalars(
            select(Settlement)
            .where(
                Settlement.group_id == group_id, Settlement.deleted_at.is_(None)
            )
            .order_by(Settlement.settled_at.desc(), Settlement.created_at.desc())
        )
    )
    names = _name_map(db, group_id)
    return [_to_read(s, names) for s in settlements]


@router.delete(
    "/{group_id}/settlements/{settlement_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_settlement(
    group_id: uuid.UUID,
    settlement_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")
    settlement = db.get(Settlement, settlement_id)
    if (
        settlement is None
        or settlement.group_id != group_id
        or settlement.deleted_at is not None
    ):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Settlement not found")
    settlement.deleted_at = datetime.now(timezone.utc)
    record_activity(
        db,
        group_id=group_id,
        actor_id=current_user.id,
        type_="settlement_removed",
        summary=f"{actor_name(current_user)} removed a payment",
    )
    db.commit()
