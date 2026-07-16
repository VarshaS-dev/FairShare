"""Pydantic schemas for expenses."""

import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class SplitEntry(BaseModel):
    member_id: uuid.UUID
    # Meaning depends on the method:
    #   exact       -> the member's amount in minor units
    #   percentage  -> the member's whole-number percent (all must sum to 100)
    #   shares      -> the member's weight (e.g. 2 means "double share")
    #   equal       -> ignored
    value: int | None = None


class ExpenseSplitInput(BaseModel):
    method: Literal["equal", "exact", "percentage", "shares"] = "equal"
    entries: list[SplitEntry] = Field(min_length=1)


class ExpenseCreate(BaseModel):
    description: str = Field(min_length=1, max_length=200)
    amount_minor: int = Field(gt=0)  # integer minor units, must be positive
    paid_by: uuid.UUID  # a member id
    split: ExpenseSplitInput
    category: str | None = Field(default=None, max_length=40)
    spent_at: date | None = None  # defaults to today


class ExpenseSplitRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    member_id: uuid.UUID
    share_minor: int


class ExpenseRead(BaseModel):
    id: uuid.UUID
    description: str
    amount_minor: int
    paid_by: uuid.UUID
    paid_by_name: str
    category: str | None
    spent_at: date
    created_at: datetime
    splits: list[ExpenseSplitRead]
