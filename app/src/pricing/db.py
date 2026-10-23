"""The connection to the pricing database: one small pool per process."""
import logging

import psycopg
from psycopg.conninfo import make_conninfo
from psycopg_pool import ConnectionPool

from pricing.settings import get_settings

log = logging.getLogger("pricing.db")
_pool: ConnectionPool | None = None


def conninfo() -> str:
    s = get_settings()
    extra = {"connect_timeout": s.database_connect_timeout, "application_name": "pricing"}
    if s.password():
        extra["password"] = s.password()
    return make_conninfo(s.database_url, **extra)


def pool() -> ConnectionPool:
    """The process's pool, opened on first use without waiting for the database."""
    global _pool
    if _pool is None:
        _pool = ConnectionPool(conninfo(), min_size=1, max_size=4, open=False, name="pricing")
        _pool.open(wait=False)
    return _pool


def close() -> None:
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


def ping() -> str:
    """'ok' if the database answers SELECT 1 within the connect timeout, else the reason."""
    try:
        with pool().connection(timeout=get_settings().database_connect_timeout) as conn:
            conn.execute("SELECT 1")
        return "ok"
    except (psycopg.Error, Exception) as error:  # the pool raises PoolTimeout, not psycopg.Error
        log.warning("database check failed: %s", type(error).__name__)
        return "unreachable"


def connect() -> psycopg.Connection:
    """A plain connection, for the worker's long-running loop."""
    return psycopg.connect(conninfo(), autocommit=True)
