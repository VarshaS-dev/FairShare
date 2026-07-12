"""Shared FastAPI dependencies."""

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.firebase import verify_id_token
from app.models.user import User


def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> User:
    """Resolve the caller from their Firebase ID token.

    Provisions a local User row the first time we see a given Firebase UID
    (just-in-time). Raises 401 if the token is missing or invalid.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "Missing or malformed Authorization header.",
        )
    id_token = authorization.split(" ", 1)[1].strip()

    try:
        claims = verify_id_token(id_token)
    except RuntimeError:
        # Server misconfiguration (no service-account key) — surface as 500.
        raise
    except Exception:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Invalid or expired token."
        )

    firebase_uid: str = claims["uid"]
    user = db.scalar(select(User).where(User.firebase_uid == firebase_uid))

    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            email=claims.get("email"),
            display_name=claims.get("name"),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    # Keep our local mirror in sync with Firebase.
    #
    # Why this matters: an ID token is a SNAPSHOT of the user's claims at the
    # moment it was minted. The token from createUserWithEmailAndPassword
    # predates updateDisplayName, so a brand-new signup's first request carries
    # no `name` claim — and we'd store display_name = NULL forever. Re-syncing
    # on each request self-heals that, and also picks up later name/email edits.
    #
    # We only overwrite when the token actually HAS a value, so a token missing
    # a claim can never blank out good data.
    token_email = claims.get("email")
    token_name = claims.get("name")
    changed = False
    if token_email and user.email != token_email:
        user.email = token_email
        changed = True
    if token_name and user.display_name != token_name:
        user.display_name = token_name
        changed = True
    if changed:
        db.commit()
        db.refresh(user)

    return user
