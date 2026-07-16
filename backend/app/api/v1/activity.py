"""Global activity feed — recent events across all the caller's groups."""

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.activity import Activity
from app.models.group import Group
from app.models.member import Member
from app.models.user import User
from app.schemas.activity import ActivityRead

router = APIRouter(tags=["activity"])


@router.get("/activity", response_model=list[ActivityRead])
def list_activity(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[ActivityRead]:
    my_group_ids = select(Member.group_id).where(
        Member.user_id == current_user.id
    )
    rows = db.execute(
        select(Activity, Group.name, User.display_name)
        .join(Group, Group.id == Activity.group_id)
        .outerjoin(User, User.id == Activity.actor_id)
        .where(Activity.group_id.in_(my_group_ids))
        .order_by(Activity.created_at.desc())
        .limit(100)
    ).all()
    return [
        ActivityRead(
            id=a.id,
            group_id=a.group_id,
            group_name=group_name,
            type=a.type,
            summary=a.summary,
            actor_name=actor_name,
            created_at=a.created_at,
        )
        for a, group_name, actor_name in rows
    ]
