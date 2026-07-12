"""Importing every model here ensures they're all registered on Base.metadata
before Alembic autogenerates migrations or the app maps relationships.
"""

from app.models.group import Group
from app.models.invite import Invite
from app.models.member import Member
from app.models.user import User

__all__ = ["User", "Group", "Member", "Invite"]
