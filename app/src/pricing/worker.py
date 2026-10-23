"""The statement worker: claims queued statement jobs and writes one Parquet file per job.

A job is a site (or ALL) and a period (a day, 2026-10-11, or a month, 2026-10). The worker reads
the period's session charges, writes them to a CSV file next to the export while it works
(`<name>.csv.part`), then converts that to Parquet with DuckDB and removes the CSV.

On SIGTERM or SIGINT it finishes the job it's working on, then exits with code 0. With
--no-graceful it installs no handler, which is what lesson 3.2 compares.
"""
import csv
import logging
import os
import signal
import socket
import sys
import time
from pathlib import Path

import duckdb
import psycopg

from pricing import db, logs
from pricing.settings import get_settings

log = logging.getLogger("pricing.worker")

CLAIM = """
    UPDATE statement_jobs
       SET status = 'running', started_at = now(), worker = %s
     WHERE id = (SELECT id FROM statement_jobs
                  WHERE status = 'queued'
                  ORDER BY id
                  FOR UPDATE SKIP LOCKED
                  LIMIT 1)
    RETURNING id, site_id, period
"""

CHARGES = """
    SELECT session_id, site_id, charger_id, started_at, ended_at, energy_kwh, idle_minutes,
           tariff_id, amount_eur
      FROM session_charges
     WHERE (%(site)s = 'ALL' OR site_id = %(site)s)
       AND to_char(started_at AT TIME ZONE 'UTC', %(fmt)s) = %(period)s
     ORDER BY started_at, session_id
"""

COLUMNS = ["session_id", "site_id", "charger_id", "started_at", "ended_at", "energy_kwh",
           "idle_minutes", "tariff_id", "amount_eur"]


class Worker:
    def __init__(self, poll: float, pace: float, graceful: bool):
        self.poll = poll
        self.pace = pace
        self.stopping = False
        self.name = socket.gethostname()
        if graceful:
            signal.signal(signal.SIGTERM, self.stop)
            signal.signal(signal.SIGINT, self.stop)

    def stop(self, signum, _frame):
        log.info("%s received: finishing the current job, then exiting", signal.Signals(signum).name)
        self.stopping = True

    def run(self, once: bool) -> int:
        export_dir = get_settings().export_dir
        log.info("statement worker %s starting: exports to %s, polling every %ss", self.name, export_dir, self.poll)
        try:
            conn = db.connect()
        except psycopg.OperationalError as error:
            log.error("database unreachable: %s", str(error).strip().splitlines()[0])
            return 1
        with conn:
            while not self.stopping:
                job = conn.execute(CLAIM, (self.name,)).fetchone()
                if job:
                    self.export(conn, *job)
                if once:
                    break
                if not job:
                    self.sleep(self.poll)
        log.info("statement worker %s stopped", self.name)
        return 0

    def sleep(self, seconds: float) -> None:
        end = time.monotonic() + seconds
        while not self.stopping and time.monotonic() < end:
            time.sleep(0.1)

    def export(self, conn, job_id: int, site_id: str, period: str) -> None:
        fmt = "YYYY-MM-DD" if len(period) == 10 else "YYYY-MM"
        target = get_settings().export_dir / "statements" / site_id / f"{period}.parquet"
        log.info("job %s: %s %s -> %s", job_id, site_id, period, target)
        started = time.monotonic()
        try:
            rows = conn.execute(CHARGES, {"site": site_id, "fmt": fmt, "period": period}).fetchall()
            target.parent.mkdir(parents=True, exist_ok=True)
            part = target.with_name(target.name.replace(".parquet", ".csv.part"))
            with part.open("w", newline="") as f:
                writer = csv.writer(f)
                writer.writerow(COLUMNS)
                for start in range(0, len(rows), 1000):
                    writer.writerows(rows[start:start + 1000])
                    f.flush()
                    if self.pace:
                        time.sleep(self.pace)
            duckdb.connect().execute(
                f"COPY (SELECT * FROM read_csv('{part}', header = true)) TO '{target}' (FORMAT parquet)"
            )
            part.unlink()
        except Exception as error:
            log.exception("job %s failed", job_id)
            conn.execute("UPDATE statement_jobs SET status = 'failed', finished_at = now(), error = %s WHERE id = %s",
                         (f"{type(error).__name__}: {error}", job_id))
            return
        conn.execute(
            "UPDATE statement_jobs SET status = 'done', finished_at = now(), rows = %s, file = %s WHERE id = %s",
            (len(rows), str(target), job_id),
        )
        log.info("job %s done: %s rows in %.1f s", job_id, len(rows), time.monotonic() - started)


def main(once: bool, poll: float, pace: float, graceful: bool) -> int:
    logs.setup()
    return Worker(poll=poll, pace=pace, graceful=graceful).run(once=once)


if __name__ == "__main__":
    sys.exit(main(once=False, poll=2.0, pace=0.0, graceful=True))
