#!/usr/bin/env bash
# Lesson 11.1, Logs and limits for the long run: the practical as a shell session.
# Run it whole from the repository root:  bash module-11/01-logs-and-limits-for-the-long-run.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-11/01-long-run
B=../../.lab/m11l01
load() { python3 ../../tools/load.py http://127.0.0.1:8700 "$1"; }
logfiles() { bash ../../tools/logfiles.sh "brightlane-$1-1"; }
docker compose down -v > /dev/null 2>&1
mkdir -p $B && python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > $B/db_password.txt

step "1. Which log driver, by default"
docker info --format 'daemon default: {{.LoggingDriver}}'
docker compose up -d --wait > /dev/null 2>&1
for s in db api proxy; do
  docker inspect -f "$s: {{.HostConfig.LogConfig.Type}} {{.HostConfig.LogConfig.Config}}" brightlane-$s-1
done

step "Break it: json-file without rotation, the Linux default"
docker compose -f compose.yaml -f json-file.yaml up -d --wait > /dev/null 2>&1
docker inspect -f 'api: {{.HostConfig.LogConfig.Type}} {{.HostConfig.LogConfig.Config}}' brightlane-api-1
load 5000
echo "--- api"; logfiles api
echo "--- proxy"; logfiles proxy
before=$(docker compose logs --no-log-prefix api | wc -l)
sleep 60
echo "the idle API, 60 s later: $(( $(docker compose logs --no-log-prefix api | wc -l) - before )) more lines"
docker compose logs --no-log-prefix api | tail -1

step "2. Rotation: json-file with max-size and max-file"
docker compose -f compose.yaml -f rotated.yaml up -d --wait > /dev/null 2>&1
docker inspect -f 'api: {{.HostConfig.LogConfig.Type}} {{.HostConfig.LogConfig.Config}}' brightlane-api-1
load 5000
echo "--- api"; logfiles api
echo "--- proxy"; logfiles proxy
echo "docker logs shows $(docker compose logs --no-log-prefix api | wc -l | tr -d ' ') lines of the API's log"

step "3. JSON logs from the app"
docker compose -f compose.yaml -f rotated.yaml -f json-logs.yaml up -d --wait > /dev/null 2>&1
load 200
docker compose logs --no-log-prefix api | grep '"uvicorn.access"' | tail -1
docker compose logs --no-log-prefix api | python3 ../../tools/log_summary.py

step "4. Limits and reservations"
docker compose -f compose.yaml -f limits.yaml up -d --wait > /dev/null 2>&1
docker inspect -f 'Memory={{.HostConfig.Memory}} MemoryReservation={{.HostConfig.MemoryReservation}} NanoCpus={{.HostConfig.NanoCpus}} CpuShares={{.HostConfig.CpuShares}} PidsLimit={{.HostConfig.PidsLimit}}' brightlane-api-1
docker compose exec api sh -c 'cd /sys/fs/cgroup && for f in memory.max memory.low cpu.max cpu.weight pids.max pids.current; do echo "$f: $(cat $f)"; done'

step "Break it: more threads than the process limit"
docker compose exec api python -c '
import threading, time
started = []
try:
    for _ in range(200):
        t = threading.Thread(target=time.sleep, args=(3,), daemon=True)
        t.start()
        started.append(t)
except RuntimeError as error:
    print(f"{len(started)} threads started, then: {error}")'
docker compose ps --format '{{.Service}}: {{.Status}}' api
load 100

step "Clean up"
docker compose down -v > /dev/null 2>&1 && echo "stack and volumes removed"
rm -rf $B
