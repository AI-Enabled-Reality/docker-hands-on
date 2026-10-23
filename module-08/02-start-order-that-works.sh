#!/usr/bin/env bash
# Lesson 8.2, Start order that works: healthchecks and depends_on. The practical as a shell session.
# Run it whole from the repository root:  bash module-08/02-start-order-that-works.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
TIMEFORMAT='took %R s'
cd module-08
quote() {
  curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
    -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
}
docker compose -f 01-the-stack/compose.yaml down -v > /dev/null 2>&1
docker compose -f 02-start-order/compose.yaml down -v > /dev/null 2>&1
docker rm -f m08l02-api > /dev/null 2>&1

step "1. Break it: lesson 8.1's stack, from an empty volume"
docker compose -f 01-the-stack/compose.yaml up -d > /dev/null 2>&1
sleep 15
docker inspect -f '{{.Name}}: {{.State.Status}}, restarted {{.RestartCount}} times' brightlane-worker-1
docker compose -f 01-the-stack/compose.yaml logs --no-log-prefix worker | grep -c "database unreachable"
docker compose -f 01-the-stack/compose.yaml logs --no-log-prefix worker | grep -m1 "database unreachable" | cut -d' ' -f3-
docker compose -f 01-the-stack/compose.yaml down -v > /dev/null 2>&1

step "2. A HEALTHCHECK in the image"
docker build -q -f 02-start-order/Dockerfile.healthcheck -t brightlane/pricing:0.8-health ../app > /dev/null
docker image inspect --format '{{json .Config.Healthcheck.Test}}' brightlane/pricing:0.8-health | cut -c1-90
docker run -d --name m08l02-api brightlane/pricing:0.8-health > /dev/null
for i in 1 2 3; do docker ps --filter name=m08l02-api --format '{{.Status}}'; sleep 1; done
docker exec m08l02-api python -c "import urllib.request, urllib.error
try: urllib.request.urlopen('http://127.0.0.1:8000/health/ready')
except urllib.error.HTTPError as e: print('ready?', e.code, e.read().decode())"
docker rm -f m08l02-api > /dev/null

step "3. The stack with healthchecks and depends_on"
cd 02-start-order
time docker compose up -d --wait > /dev/null 2>&1
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
docker inspect $(docker compose ps -aq) | python3 ../../tools/compose_timeline.py
docker compose logs --no-log-prefix migrate
quote

step "4. Healthchecks report; they don't restart"
docker compose stop db > /dev/null 2>&1
sleep 20
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}' | grep -E "SERVICE|api|db"
docker inspect -f 'api: restarted {{.RestartCount}} times, {{.State.Health.FailingStreak}} failed checks in a row' brightlane-api-1
docker compose start db > /dev/null 2>&1
sleep 8
docker compose ps --format 'table {{.Service}}\t{{.Status}}' | grep -E "SERVICE|api"

step "5. Up again: migrate has nothing to do"
docker compose down > /dev/null 2>&1
time docker compose up -d --wait > /dev/null 2>&1
docker compose logs --no-log-prefix migrate

step "Clean up"
docker compose down -v > /dev/null 2>&1 && echo "stack and volumes removed"
docker image rm brightlane/pricing:0.8-health > /dev/null
