"""Schemas for the cross-group overview (consolidated per-person balances)."""

import uuid

from pydantic import BaseModel


class OverviewGroupBalance(BaseModel):
    group_id: uuid.UUID
    group_name: str
    balance_minor: int  # + they owe me in this group, - I owe them


class OverviewPerson(BaseModel):
    user_id: uuid.UUID | None  # null for a non-user placeholder (single group)
    name: str
    currency: str
    net_minor: int  # aggregated across groups (this currency)
    breakdown: list[OverviewGroupBalance]


class OverviewRead(BaseModel):
    people: list[OverviewPerson]
