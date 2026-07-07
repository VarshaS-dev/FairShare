"""User model.

Firebase owns authentication; this row is our local mirror of an authenticated
user, linked by their stable `firebase_uid`. Everything the app owns (groups,
expenses, ...) keys off `users.id`.
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class User(Base):
    __tablename__ = "users"

    # UUID primary key (not a serial int): non-guessable and safe to expose in
    # URLs/APIs without leaking how many users exist.
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)

    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(320), index=True)
    display_name: Mapped[str | None] = mapped_column(String(120))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
