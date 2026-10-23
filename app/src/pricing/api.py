"""The pricing API: tariffs, quotes and statement jobs over HTTP."""
import logging
import platform
import socket
from contextlib import asynccontextmanager
from datetime import UTC, date, datetime
from decimal import Decimal
from importlib.metadata import version

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from pricing import db, logs
from pricing.quotes import price, tariff_at
from pricing.settings import get_settings

log = logging.getLogger("pricing.api")
VERSION = version("brightlane-pricing")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logs.setup()
    s = get_settings()
    log.info("pricing API %s starting (environment %s, build %s)", VERSION, s.environment, s.build)
    yield
    db.close()
    log.info("pricing API stopped")


app = FastAPI(title="Brightlane pricing API", version=VERSION, lifespan=lifespan)


@app.get("/health/live")
def live():
    """Is the process working at all? Checks nothing else."""
    return {"status": "ok"}


@app.get("/health/ready")
def ready():
    """Can it serve requests now? Not without its database."""
    checks = {"database": db.ping()}
    if all(state == "ok" for state in checks.values()):
        return {"status": "ready", "checks": checks}
    return JSONResponse(status_code=503, content={"status": "not ready", "checks": checks})


@app.get("/version")
def version_info():
    return {
        "version": VERSION,
        "build": get_settings().build,
        "python": platform.python_version(),
        "hostname": socket.gethostname(),
    }


@app.get("/sites/{site_id}/tariff")
def current_tariff(site_id: str):
    with db.pool().connection() as conn:
        tariff = tariff_at(conn, site_id, datetime.now(UTC).date())
    if tariff is None:
        raise HTTPException(status_code=404, detail=f"no tariff for {site_id}")
    return tariff.__dict__


class QuoteRequest(BaseModel):
    site_id: str = Field(pattern=r"^site-[NCVM]\d{2}$", examples=["site-N03"])
    energy_kwh: Decimal = Field(gt=0, le=500, decimal_places=3)
    idle_minutes: int = Field(default=0, ge=0, le=1440)
    on: date | None = None


@app.post("/quotes")
def quote(request: QuoteRequest):
    day = request.on or datetime.now(UTC).date()
    with db.pool().connection() as conn:
        tariff = tariff_at(conn, request.site_id, day)
        if tariff is None:
            raise HTTPException(status_code=404, detail=f"no tariff for {request.site_id} on {day}")
        result = price(tariff, request.energy_kwh, request.idle_minutes)
        conn.execute(
            "INSERT INTO quotes (site_id, energy_kwh, idle_minutes, tariff_id, amount_eur) VALUES (%s, %s, %s, %s, %s)",
            (request.site_id, request.energy_kwh, request.idle_minutes, tariff.tariff_id, result["amount_eur"]),
        )
    return result


class StatementRequest(BaseModel):
    site_id: str = Field(pattern=r"^(site-[NCVM]\d{2}|ALL)$", examples=["site-N03", "ALL"])
    period: str = Field(pattern=r"^2\d{3}-\d{2}(-\d{2})?$", examples=["2026-10-11", "2026-10"])


@app.post("/statements", status_code=202)
def request_statement(request: StatementRequest):
    with db.pool().connection() as conn:
        job_id = conn.execute(
            "INSERT INTO statement_jobs (site_id, period) VALUES (%s, %s) RETURNING id",
            (request.site_id, request.period),
        ).fetchone()[0]
    log.info("statement job %s queued: %s %s", job_id, request.site_id, request.period)
    return {"job_id": job_id, "status": "queued"}


@app.get("/statements/{job_id}")
def statement_status(job_id: int):
    with db.pool().connection() as conn:
        row = conn.execute(
            "SELECT id, site_id, period, status, worker, rows, file, error FROM statement_jobs WHERE id = %s",
            (job_id,),
        ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail=f"no statement job {job_id}")
    keys = ("job_id", "site_id", "period", "status", "worker", "rows", "file", "error")
    return dict(zip(keys, row))
