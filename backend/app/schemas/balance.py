"""Schemas for computed balances and suggested settlements."""

import uuid

from pydantic import BaseModel


class MemberBalance(BaseModel):
    member_id: uuid.UUID
    name: str
    # Net position in minor units: positive = they're owed; negative = they owe.
    net_minor: int


class SuggestedPayment(BaseModel):
    """A single transfer in the simplified who-pays-whom plan (not yet a
    recorded settlement — that's Slice 6)."""

    from_member_id: uuid.UUID
    from_name: str
    to_member_id: uuid.UUID
    to_name: str
    amount_minor: int


class BalancesRead(BaseModel):
    currency: str
    me_member_id: uuid.UUID | None
    balances: list[MemberBalance]
    settlements: list[SuggestedPayment]
