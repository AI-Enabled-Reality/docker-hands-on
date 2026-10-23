#!/usr/bin/env bash
# Lesson 8.1, From docker run to compose.yaml: the practical as a shell session.
# Run it whole from the repository root:  bash module-08/01-from-docker-run-to-compose.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
# Compose looks for compose.yaml in the current folder.
cd module-08/01-the-stack
quote() {
  curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
    -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
}
n03() { docker compose exec db psql -U pricing -d pricing -tAc "SELECT tariff_id || '  ' || price_per_kwh FROM tariffs WHERE site_id = 'site-N03' ORDER BY valid_from"; }
# Wait until the database answers and its seed is loaded.
wait_db() {
  for i in $(seq 1 90); do
    docker compose exec db psql -U pricing -d pricing -tAc "SELECT 1 FROM session_charges LIMIT 1" > /dev/null 2>&1 && return
    sleep 1
  done
  echo "the database isn't ready after 90 s: docker compose logs db"
}
docker compose down -v > /dev/null 2>&1

step "1. The whole stack, one command"
docker compose config --services
docker compose up -d --build 2>&1 | grep -E "(Network|Volume) .* Created|Image .* Built|Container .* Started" | sed -E 's/^ +//' | awk '!seen[$0]++'
wait_db
docker compose ps --format 'table {{.Name}}\t{{.Service}}\t{{.Image}}\t{{.Ports}}'

step "2. A quote, through the proxy"
quote

step "3. Service names are DNS names"
docker compose exec api getent hosts db worker proxy

step "4. What Compose created, and how it knows"
docker network ls --filter label=com.docker.compose.project=brightlane --format '{{.Name}}'
docker volume ls --filter label=com.docker.compose.project=brightlane --format '{{.Name}}'
docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}} {{index .Config.Labels "com.docker.compose.service"}}' brightlane-db-1

step "5. Logs and exec, by service"
docker compose logs --no-log-prefix db | grep -E "initdb.d|init process complete"
docker compose exec db psql -U pricing -d pricing -tAc "SELECT count(*) FROM session_charges"

step "6. down, then up: the data stays"
docker compose exec db psql -U pricing -d pricing -qc "INSERT INTO tariffs SELECT 'tar-site-N03-3', site_id, 0.52, idle_fee_per_min, DATE '2026-11-01' FROM tariffs WHERE tariff_id = 'tar-site-N03-2'"
docker compose down 2>&1 | grep -E "Removed" | sed -E 's/^ +//' | awk '!seen[$0]++'
docker volume ls --filter label=com.docker.compose.project=brightlane --format '{{.Name}}'
docker compose up -d > /dev/null 2>&1
wait_db
n03

step "7. Break it: down -v"
docker compose down -v 2>&1 | grep -E "Volume .* Removed" | sed -E 's/^ +//' | awk '!seen[$0]++'
docker compose up -d > /dev/null 2>&1
wait_db
n03

step "8. The version key"
{ echo 'version: "3.8"'; cat compose.yaml; } > ../../.lab/compose-with-version.yaml
docker compose -f ../../.lab/compose-with-version.yaml --project-directory . config -q 2>&1 | sed -E 's/^time="[^"]+" level=//; s|"/[^"]*/\.lab/|".lab/|'
rm ../../.lab/compose-with-version.yaml

step "Clean up"
docker compose down -v 2>&1 | grep -E "Removed" | sed -E 's/^ +//' | awk '!seen[$0]++'
