#!/usr/bin/env bash
# Lesson 9.3, Scaling a stateless service: the practical as a shell session.
# Run it whole from the repository root:  bash module-09/03-scaling-a-stateless-service.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-09/03-scaling
B=../../.lab/m09l03
# Send 30 requests through the proxy and count which API container answered each.
answered_by() {
  for i in $(seq 1 30); do
    curl -s http://127.0.0.1:8700/version | python3 -c 'import json, sys; print(json.load(sys.stdin)["hostname"])'
  done | sort | uniq -c
}
sql() { docker compose exec db psql -U pricing -d pricing -tAc "$1"; }
docker compose -f compose.yaml -f static-proxy.yaml down -v > /dev/null 2>&1
mkdir -p $B && python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > $B/db_password.txt

step "1. Break it: three API containers, one fixed host port"
docker compose -f compose.yaml -f fixed-port.yaml up -d --wait --scale api=3 2>&1 | grep -oE "Bind for [0-9.]+:[0-9]+ failed: port is already allocated" | sort -u
docker compose ps -a --format '{{.Name}}: {{.Status}}' api
docker compose -f compose.yaml -f fixed-port.yaml down -v > /dev/null 2>&1

step "2. Three API containers behind the proxy"
docker compose up -d --wait --scale api=3 > /dev/null 2>&1
docker compose ps --format '{{.Name}}: {{.Status}}' api
docker compose exec proxy nslookup api 127.0.0.11 2>&1 | grep -E "^Address: "
answered_by

step "3. Break it: a proxy that looked the name up once"
docker compose down -v > /dev/null 2>&1
docker compose -f compose.yaml -f static-proxy.yaml up -d --wait > /dev/null 2>&1
docker compose -f compose.yaml -f static-proxy.yaml up -d --wait --scale api=3 > /dev/null 2>&1
docker compose ps --format '{{.Name}}: {{.Status}}' api
answered_by
echo "--- back to the configuration with the resolver"
before=$(docker compose ps -q proxy | cut -c1-12)
docker compose up -d --wait --scale api=3 > /dev/null 2>&1
echo "proxy container: $before before up, $(docker compose ps -q proxy | cut -c1-12) after"
docker compose up -d --wait --scale api=3 --force-recreate --no-deps proxy > /dev/null 2>&1
echo "proxy container: $(docker compose ps -q proxy | cut -c1-12) after --force-recreate"
answered_by

step "4. Three workers, one queue"
docker compose up -d --wait --scale api=3 --scale worker=3 > /dev/null 2>&1
sql "INSERT INTO statement_jobs (site_id, period) SELECT 'ALL', '2026-10-' || lpad(d::text, 2, '0') FROM generate_series(1, 12) AS d" > /dev/null
for i in $(seq 1 60); do [ "$(sql "SELECT count(*) FROM statement_jobs WHERE status IN ('queued', 'running')")" = "0" ] && break; sleep 1; done
sql "SELECT worker || ': ' || count(*) || ' jobs, ' || sum(rows) || ' rows' FROM statement_jobs GROUP BY worker ORDER BY worker"
sql "SELECT count(*) || ' jobs done, ' || count(DISTINCT id) || ' different jobs' FROM statement_jobs WHERE status = 'done'"
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' | grep brightlane | sort | awk '{print $1, $2}'

step "Clean up"
docker compose down -v > /dev/null 2>&1 && echo "stack and volumes removed"
rm -rf $B
