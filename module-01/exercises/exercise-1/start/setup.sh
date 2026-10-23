#!/usr/bin/env bash
# Starts the pricing database for exercise 1.1 (run from the repository root).
set -eu
docker rm -f m01x1-db >/dev/null 2>&1 || true
docker run -d --name m01x1-db -e POSTGRES_PASSWORD=pricing-lab-only \
  --memory 192m --cpus 0.25 postgres:18.6-trixie >/dev/null
for i in $(seq 1 30); do docker exec m01x1-db pg_isready -q 2>/dev/null && break; sleep 1; done
docker exec m01x1-db pg_isready
echo "m01x1-db is running. Now find the answers."
