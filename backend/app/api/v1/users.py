"""User endpoints."""

from fastapi import APIRouter, Depends

from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.user import UserRead

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserRead)
def read_me(current_user: User = Depends(get_current_user)) -> User:
    """Return the authenticated caller's local user record.

    Doubles as the smoke test for the whole auth bridge: a valid Firebase token
    in, your User row out.
    """
    return current_user
