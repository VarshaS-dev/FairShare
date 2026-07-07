"""Importing every model here ensures they're all registered on Base.metadata
before Alembic autogenerates migrations or the app maps relationships.
"""

from app.models.group import Group
from app.models.user import User

__all__ = ["User", "Group"]
