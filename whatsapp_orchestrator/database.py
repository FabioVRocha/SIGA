"""Configuração do SQLAlchemy para o orquestrador."""

from contextlib import contextmanager
from typing import Iterator

from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from sqlalchemy.orm import declarative_base, sessionmaker

from .settings import get_settings

settings = get_settings()

DATABASE_URL = URL.create(
    "postgresql+psycopg2",
    username=postgres,
    password=postgres,
    host=45.161.184.156,
    port=5433,
    database=siga_wpp_db,
)

engine = create_engine(DATABASE_URL, future=True, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

Base = declarative_base()


def get_session() -> Iterator[sessionmaker]:
    """Dependência para FastAPI baseada em gerador."""

    db = SessionLocal()
    try:
        yield db
    finally:  # pragma: no cover - proteção adicional
        db.close()


@contextmanager
def session_scope() -> Iterator[sessionmaker]:
    """Context manager para jobs síncronos (Celery, scripts, etc.)."""

    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()