"""Aggregates all v1 routers under a single /api/v1 prefix."""

from fastapi import APIRouter

from app.api.v1 import (
    activity,
    balances,
    expenses,
    groups,
    invites,
    settlements,
    users,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(users.router)
api_router.include_router(groups.router)
api_router.include_router(invites.router)
api_router.include_router(expenses.router)
api_router.include_router(balances.router)
api_router.include_router(settlements.router)
api_router.include_router(activity.router)
