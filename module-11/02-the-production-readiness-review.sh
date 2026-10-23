#!/usr/bin/env bash
# Lesson 11.2, The production readiness review: the practical as a shell session.
# Run it whole from the repository root:  bash module-11/02-the-production-readiness-review.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-11/02-readiness
B=../../.lab/m11l02
PROD="-f compose.yaml -f compose.prod.yaml -f compose.hardened.yaml"
quote() {
  curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
    -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
}
docker compose -f contractor/compose.yaml down -v > /dev/null 2>&1
docker compose $PROD down -v > /dev/null 2>&1
mkdir -p $B && python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > $B/db_password.txt

step "Break it: the contractor's stack"
docker compose -f contractor/compose.yaml up -d --build > /dev/null 2>&1
for _ in $(seq 60); do
  curl -sf -o /dev/null -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
    -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}' && break
  sleep 1
done
quote
python3 ../../tools/readiness.py m11l02-contractor
echo "exit code: $?"
docker compose -f contractor/compose.yaml down -v > /dev/null 2>&1

step "2. The course's production stack"
docker compose $PROD up -d --wait > /dev/null 2>&1
docker compose $PROD ps --format 'table {{.Service}}\t{{.Status}}'
quote
python3 ../../tools/readiness.py brightlane
echo "exit code: $?"

step "Clean up"
docker compose $PROD down -v > /dev/null 2>&1 && echo "stack and volumes removed"
docker image rm brightlane/pricing:latest postgres:18 nginx:alpine > /dev/null 2>&1 && echo "the contractor's images removed"
rm -rf $B
