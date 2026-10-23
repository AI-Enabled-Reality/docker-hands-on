#!/usr/bin/env bash
# Start a pricing database container and load the schema and the seed, as lesson 3.1 does by hand.
#   bash tools/pricing-db.sh <container-name> [extra docker run options...]
# Example: bash tools/pricing-db.sh m03l02-db
# Lab credentials: user pricing, password pricing-lab-only, database pricing.
set -eu
name="$1"; shift
docker rm -f -v "$name" >/dev/null 2>&1 || true
docker run -d --name "$name" -e POSTGRES_USER=pricing -e POSTGRES_PASSWORD=pricing-lab-only \
  -e POSTGRES_DB=pricing "$@" postgres:18.6-trixie >/dev/null
for i in $(seq 1 60); do docker exec "$name" pg_isready -U pricing -d pricing -q 2>/dev/null && break; sleep 1; done
docker cp app/db/init/. "$name":/tmp/init/ >/dev/null
docker exec "$name" psql -U pricing -d pricing -q -v ON_ERROR_STOP=1 -f /tmp/init/01-schema.sql -f /tmp/init/02-seed.sql >/dev/null
echo "$name: $(docker exec "$name" psql -U pricing -d pricing -tAc "SELECT count(*) FROM session_charges") session charges loaded"
