"""Database engine, session factory, and the declarative Base.

We use SYNCHRONOUS SQLAlchemy (simpler to read and debug; ample for our scale).
FastAPI runs sync path operations in a threadpool, so a blocking DB call here
doesn't stall the event loop.
"""

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import settings

# `pool_pre_ping` transparently checks a connection is alive before using it,
# avoiding "server closed the connection" errors after idle periods.
engine = create_engine(settings.database_url, pool_pre_ping=True, echo=False)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """Base class all ORM models inherit from. Alembic reads its metadata."""


def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency: yields a request-scoped session, always closed."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
