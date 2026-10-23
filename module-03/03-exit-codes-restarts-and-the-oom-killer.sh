#!/usr/bin/env bash
# Lesson 3.3, When containers die: exit codes, restarts and the OOM killer.
# Run it whole from the repository root:  bash module-03/03-exit-codes-restarts-and-the-oom-killer.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
DB_URL=postgresql://pricing:pricing-lab-only@localhost:5432/pricing

step "0. The pricing database, loaded, and the image"
bash tools/pricing-db.sh m03l03-db
docker build -q -f module-02/03-entrypoint-and-cmd/Dockerfile -t brightlane/pricing:0.3 app

step "1. Exit codes: who says what"
docker run --rm alpine:3.24.3 sh -c 'exit 3'; echo "exit code: $?"
docker run --rm alpine:3.24.3 no-such-program; echo "exit code: $?"
docker run --rm alpine:3.24.3 /etc/hostname; echo "exit code: $?"
docker run --rm --memory 1k alpine:3.24.3 true; echo "exit code: $?"

step "2. A worker that can't reach its database, with --restart on-failure:3"
docker run -d --name m03l03-lost --restart on-failure:3 -e PRICING_DATABASE_URL=postgresql://pricing@db:5432/pricing brightlane/pricing:0.3 worker
sleep 8
docker inspect --format 'status={{.State.Status}} exit={{.State.ExitCode}} restarts={{.RestartCount}}' m03l03-lost
docker logs -t m03l03-lost 2>&1 | grep starting | cut -c1-22

step "3. --restart always: even a clean exit is restarted, until you stop it"
docker run -d --name m03l03-always --restart always alpine:3.24.3 sh -c 'sleep 1; exit 0'
sleep 6
docker inspect --format 'status={{.State.Status}} restarts={{.RestartCount}}' m03l03-always
docker stop m03l03-always
sleep 3
docker inspect --format 'status={{.State.Status}} restarts={{.RestartCount}}' m03l03-always

step "4. The October statement for every site, with 256 MiB"
docker exec m03l03-db psql -U pricing -d pricing -qc "INSERT INTO statement_jobs (site_id, period) VALUES ('ALL', '2026-10')"
docker run -d --name m03l03-big --network container:m03l03-db --memory 256m --memory-swap 256m -e PRICING_DATABASE_URL=$DB_URL brightlane/pricing:0.3 worker
sleep 4
docker logs m03l03-big 2>&1 | grep done | cut -c25-
docker exec m03l03-big cat /sys/fs/cgroup/memory.peak
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" m03l03-big
docker rm -f m03l03-big

step "5. Break it: the same statement with a 96 MiB limit"
docker exec m03l03-db psql -U pricing -d pricing -qc "INSERT INTO statement_jobs (site_id, period) VALUES ('ALL', '2026-10')"
docker run --name m03l03-small --network container:m03l03-db --memory 96m --memory-swap 96m -e PRICING_DATABASE_URL=$DB_URL brightlane/pricing:0.3 worker --once
echo "exit code: $?"
docker inspect --format 'OOMKilled={{.State.OOMKilled}} exit={{.State.ExitCode}}' m03l03-small
sleep 1
docker events --since 1m --until 0s --filter container=m03l03-small --filter event=oom --format '{{.Action}} {{.Actor.Attributes.name}}'
docker exec m03l03-db psql -U pricing -d pricing -tAc "SELECT id, status FROM statement_jobs ORDER BY id"

step "6. CPU limits slow you down instead"
for cpus in 2 0.25; do
  docker exec m03l03-db psql -U pricing -d pricing -qc "INSERT INTO statement_jobs (site_id, period) VALUES ('ALL', '2026-10')"
  docker run --rm --network container:m03l03-db --cpus $cpus -e PRICING_DATABASE_URL=$DB_URL brightlane/pricing:0.3 worker --once 2>&1 | grep done | sed "s/.*done/--cpus $cpus: done/"
done

step "7. Open files: check the limit, then set it"
docker run --rm alpine:3.24.3 sh -c 'ulimit -n'
docker run --rm --ulimit nofile=65536:65536 alpine:3.24.3 sh -c 'ulimit -n'

step "Clean up"
docker rm -f m03l03-lost m03l03-always m03l03-small
docker rm -f -v m03l03-db
