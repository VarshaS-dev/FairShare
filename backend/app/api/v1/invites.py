"""Invite endpoints — preview and accept (the claim/merge lives here)."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.group import Group
from app.models.invite import Invite
from app.models.member import Member
from app.models.user import User
from app.schemas.group import GroupRead
from app.schemas.invite import InvitePreview

router = APIRouter(prefix="/invites", tags=["invites"])


def _is_member(db: Session, group_id, user_id) -> bool:
    return (
        db.scalar(
            select(Member.id).where(
                Member.group_id == group_id, Member.user_id == user_id
            )
        )
        is not None
    )


def _load_valid_invite(db: Session, code: str) -> Invite:
    invite = db.scalar(select(Invite).where(Invite.code == code.strip().upper()))
    if invite is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Invite not found.")
    if invite.accepted_at is not None:
        raise HTTPException(status.HTTP_410_GONE, "This invite has already been used.")
    if invite.expires_at is not None and invite.expires_at < datetime.now(
        timezone.utc
    ):
        raise HTTPException(status.HTTP_410_GONE, "This invite has expired.")
    return invite


@router.get("/{code}", response_model=InvitePreview)
def preview_invite(
    code: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> InvitePreview:
    invite = _load_valid_invite(db, code)
    group = db.get(Group, invite.group_id)
    assert group is not None  # invite has a FK to a live group

    claim_name = None
    if invite.member_id is not None:
        placeholder = db.get(Member, invite.member_id)
        claim_name = placeholder.name if placeholder is not None else None

    return InvitePreview(
        group_name=group.name,
        currency=group.currency,
        claim_name=claim_name,
        already_member=_is_member(db, invite.group_id, current_user.id),
    )


@router.post("/{code}/accept", response_model=GroupRead)
def accept_invite(
    code: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> Group:
    invite = _load_valid_invite(db, code)
    group = db.get(Group, invite.group_id)
    assert group is not None

    if _is_member(db, invite.group_id, current_user.id):
        raise HTTPException(status.HTTP_409_CONFLICT, "You're already in this group.")

    if invite.member_id is not None:
        # CLAIM/MERGE: link the placeholder to this user instead of adding a new
        # member, so their existing history (and future balances) carry over.
        placeholder = db.get(Member, invite.member_id)
        if placeholder is None or placeholder.group_id != invite.group_id:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "This invite is no longer valid."
            )
        if placeholder.user_id is not None:
            raise HTTPException(
                status.HTTP_409_CONFLICT, "This spot has already been claimed."
            )
        placeholder.user_id = current_user.id
    else:
        # Generic invite: add the user as a fresh member.
        db.add(
            Member(
                group_id=invite.group_id,
                user_id=current_user.id,
                name=current_user.display_name or current_user.email or "Member",
                role="member",
            )
        )

    invite.accepted_at = datetime.now(timezone.utc)
    invite.accepted_by = current_user.id
    db.commit()
    db.refresh(group)
    return group
