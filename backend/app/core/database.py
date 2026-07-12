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
#
# `connect_timeout` (seconds) makes us FAIL FAST when Postgres is unreachable
# (e.g. the Docker container is stopped). Without it, a request blocks forever
# and the app shows an eternal spinner instead of its error state. Better to
# return an error in 5s that the UI can surface, with a Retry button.
engine = create_engine(
    settings.database_url,
    pool_pre_ping=True,
    echo=False,
    connect_args={"connect_timeout": 5},
)

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
