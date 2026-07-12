"""Group endpoints. All require a valid Firebase token (via get_current_user)."""

import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.group import Group
from app.models.invite import Invite
from app.models.member import Member
from app.models.user import User
from app.schemas.group import GroupCreate, GroupDetailRead, GroupRead
from app.schemas.invite import InviteCreate, InviteRead
from app.schemas.member import MemberCreate, MemberRead

router = APIRouter(prefix="/groups", tags=["groups"])


def _is_member(db: Session, group_id: uuid.UUID, user_id: uuid.UUID) -> bool:
    return (
        db.scalar(
            select(Member.id).where(
                Member.group_id == group_id, Member.user_id == user_id
            )
        )
        is not None
    )


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
    db.flush()  # assign group.id before we reference it below

    # The creator is automatically the group's first member.
    db.add(
        Member(
            group_id=group.id,
            user_id=current_user.id,
            name=current_user.display_name or "Me",
            role="creator",
        )
    )
    db.commit()
    db.refresh(group)
    return group


@router.get("", response_model=list[GroupRead])
def list_groups(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[Group]:
    # "My groups" = groups where I'm a member (the creator is a member too).
    stmt = (
        select(Group)
        .join(Member, Member.group_id == Group.id)
        .where(Member.user_id == current_user.id)
        .order_by(Group.created_at.desc())
    )
    return list(db.scalars(stmt))


@router.get("/{group_id}", response_model=GroupDetailRead)
def get_group(
    group_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> GroupDetailRead:
    group = db.get(Group, group_id)
    # Only members may view a group. Return 404 (not 403) so we don't reveal a
    # group's existence to people who aren't in it.
    if group is None or not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    # Outer-join the linked user so we can show their CURRENT name. `member.name`
    # is a snapshot — authoritative only for non-user placeholders, where it's
    # the sole source of truth. This kills stale names for real users.
    rows = db.execute(
        select(Member, User)
        .outerjoin(User, User.id == Member.user_id)
        .where(Member.group_id == group_id)
        .order_by(Member.created_at)
    ).all()

    members = [
        MemberRead(
            id=m.id,
            name=(u.display_name if (u is not None and u.display_name) else m.name),
            role=m.role,
            user_id=m.user_id,
            created_at=m.created_at,
        )
        for m, u in rows
    ]

    return GroupDetailRead(
        id=group.id,
        name=group.name,
        currency=group.currency,
        created_at=group.created_at,
        members=members,
    )


@router.post(
    "/{group_id}/members",
    response_model=MemberRead,
    status_code=status.HTTP_201_CREATED,
)
def add_member(
    group_id: uuid.UUID,
    payload: MemberCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Member:
    """Add a member — either a non-user placeholder (`name`) or an existing
    FairShare user (`email`). Only people already in the group may add others.
    """
    group = db.get(Group, group_id)
    if group is None or not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    if payload.email:
        email = payload.email.strip()
        # Case-insensitive lookup: nobody types their email consistently.
        target = db.scalar(
            select(User).where(func.lower(User.email) == email.lower())
        )
        if target is None:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND,
                "No FairShare user with that email. Add them by name instead.",
            )
        if _is_member(db, group_id, target.id):
            raise HTTPException(
                status.HTTP_409_CONFLICT, "They're already in this group."
            )
        member = Member(
            group_id=group_id,
            user_id=target.id,
            name=target.display_name or target.email or "Member",
            role="member",
        )
    else:
        member = Member(
            group_id=group_id,
            user_id=None,  # placeholder — claimed when they sign up (Slice 3d)
            name=payload.name.strip(),  # type: ignore[union-attr]
            role="member",
        )

    db.add(member)
    db.commit()
    db.refresh(member)
    return member


@router.delete(
    "/{group_id}/members/{member_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def remove_member(
    group_id: uuid.UUID,
    member_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Remove a member from a group.

    Only group members may do this, and the creator can't be removed. (Later,
    once expenses exist, we'll also block removing anyone with a non-zero
    balance — you shouldn't be able to erase a debt by deleting the debtor.)
    """
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    member = db.get(Member, member_id)
    if member is None or member.group_id != group_id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Member not found")
    if member.role == "creator":
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST, "The group creator can't be removed."
        )

    db.delete(member)
    db.commit()


# Unambiguous alphabet: no 0/O or 1/I to confuse people typing a code.
_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def _new_code(length: int = 8) -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(length))


@router.post(
    "/{group_id}/invites",
    response_model=InviteRead,
    status_code=status.HTTP_201_CREATED,
)
def create_invite(
    group_id: uuid.UUID,
    payload: InviteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Invite:
    """Create a shareable invite code. If `member_id` is given, accepting it
    claims that placeholder (merge); otherwise it's a generic group join.
    """
    if not _is_member(db, group_id, current_user.id):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Group not found")

    if payload.member_id is not None:
        placeholder = db.get(Member, payload.member_id)
        if placeholder is None or placeholder.group_id != group_id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Member not found")
        if placeholder.user_id is not None:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "That member already has an account.",
            )

    # Generate a unique code (retry on the rare collision).
    code = _new_code()
    for _ in range(5):
        if db.scalar(select(Invite.id).where(Invite.code == code)) is None:
            break
        code = _new_code()

    invite = Invite(
        code=code,
        group_id=group_id,
        member_id=payload.member_id,
        created_by=current_user.id,
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)
    return invite
