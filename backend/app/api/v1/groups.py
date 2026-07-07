"""Group endpoints. All require a valid Firebase token (via get_current_user)."""

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.group import Group
from app.models.user import User
from app.schemas.group import GroupCreate, GroupRead

router = APIRouter(prefix="/groups", tags=["groups"])


@router.post("", response_model=GroupRead, status_code=status.HTTP_201_CREATED)
def create_group(
    payload: GroupCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Group:
    group = Group(
        name=payload.name.strip(),
        currency=payload.currency.upper(),
        created_by=current_user.id,
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    return group


@router.get("", response_model=list[GroupRead])
def list_groups(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Group]:
    # Slice 2: "my groups" = groups I created. Slice 3 generalizes this to
    # membership (groups where I'm a member, not just the creator).
    stmt = (
        select(Group)
        .where(Group.created_by == current_user.id)
        .order_by(Group.created_at.desc())
    )
    return list(db.scalars(stmt))
