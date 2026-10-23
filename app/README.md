# Brightlane pricing service

The application this course containerizes: a FastAPI **pricing API** and a **statement worker**,
both backed by the PostgreSQL pricing database. One package, one command:

- `pricing api`: serve the API (`/health/live`, `/health/ready`, `/version`,
  `/sites/{site_id}/tariff`, `/quotes`, `/statements`).
- `pricing worker`: claim queued statement jobs and write Parquet exports.
- `pricing version`: print the version.

Settings come from environment variables with the prefix `PRICING_` (see `src/pricing/settings.py`).
The database schema and seed data are in `db/init/`. You don't need to change this code during the
course; the lessons change how it's built and run.
