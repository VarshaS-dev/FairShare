"""Cross-group overview — consolidated pairwise balances per person.

For every OTHER person I share groups with, sum my pairwise balance across those
groups (aggregated by user for linked members; per-group for placeholders), split
by currency. This never touches the group balance endpoints — it just aggregates.
"""

import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.group import Group
from app.models.member import Member
from app.models.user import User
from app.schemas.overview import (
    OverviewGroupBalance,
    OverviewPerson,
    OverviewRead,
)
from app.services.ledger import compute_pairwise

router = APIRouter(tags=["overview"])


@router.get("/overview", response_model=OverviewRead)
def get_overview(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> OverviewRead:
    # My member row + currency in each of my groups.
    my_memberships = db.execute(
        select(Member.id, Member.group_id, Group.name, Group.currency)
        .join(Group, Group.id == Member.group_id)
        .where(Member.user_id == current_user.id)
    ).all()

    # Accumulate per (person, currency). A linked user aggregates across groups
    # by user_id; a placeholder is keyed by its member id (single group only).
    accum: dict[tuple, dict] = {}

    for me_member_id, group_id, group_name, currency in my_memberships:
        pair = compute_pairwise(db, group_id, me_member_id)
        if not pair:
            continue

        member_rows = db.execute(
            select(Member, User)
            .outerjoin(User, User.id == Member.user_id)
            .where(Member.group_id == group_id)
        ).all()
        info = {
            m.id: (
                m.user_id,
                (u.display_name if (u is not None and u.display_name) else m.name),
            )
            for m, u in member_rows
        }

        for other_id, bal in pair.items():
            if bal == 0:
                continue
            user_id, name = info.get(other_id, (None, "Member"))
            person_key = (
                ("u", str(user_id)) if user_id is not None else ("m", str(other_id))
            )
            acc_key = (person_key, currency)
            entry = accum.get(acc_key)
            if entry is None:
                entry = {
                    "user_id": user_id,
                    "name": name,
                    "currency": currency,
                    "net": 0,
                    "breakdown": [],
                }
                accum[acc_key] = entry
            entry["net"] += bal
            entry["breakdown"].append(
                OverviewGroupBalance(
                    group_id=group_id, group_name=group_name, balance_minor=bal
                )
            )

    people = [
        OverviewPerson(
            user_id=e["user_id"],
            name=e["name"],
            currency=e["currency"],
            net_minor=e["net"],
            breakdown=e["breakdown"],
        )
        for e in accum.values()
        if e["net"] != 0
    ]
    people.sort(key=lambda p: -abs(p.net_minor))
    return OverviewRead(people=people)
