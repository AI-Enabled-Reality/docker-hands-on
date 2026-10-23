#!/usr/bin/env bash
# Lesson 3.2, PID 1, signals and a clean stop: the practical as a shell session.
# Run it whole from the repository root:  bash module-03/02-pid1-signals-and-a-clean-stop.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
DB_URL=postgresql://pricing:pricing-lab-only@localhost:5432/pricing

# Queue Tomasz's October statement for every site, start a worker, stop it 2 s into the job.
# Prints how long the stop took, the exit code, what's in the export folder and the job's status.
stop_mid_job() {
  docker exec m03l02-db psql -U pricing -d pricing -qc "INSERT INTO statement_jobs (site_id, period) VALUES ('ALL', '2026-10')"
  docker run -d --name m03l02-worker --network container:m03l02-db -e PRICING_DATABASE_URL=$DB_URL "$@" > /dev/null
  sleep 2
  { /usr/bin/time -p docker stop m03l02-worker > /dev/null; } 2>&1 | awk '/^real/ {print "stop took " $2 " s"}'
  docker inspect --format 'exit code {{.State.ExitCode}}' m03l02-worker
  docker cp m03l02-worker:/exports - | tar -t | grep -E "parquet|part"
  docker exec m03l02-db psql -U pricing -d pricing -tAc "SELECT 'job ' || id || ': ' || status FROM statement_jobs ORDER BY id DESC LIMIT 1"
  docker logs m03l02-worker 2>&1 | tail -2 | cut -c25-
  docker rm m03l02-worker > /dev/null
}

step "0. The pricing database, loaded (lesson 3.1's steps in one script), and the images"
bash tools/pricing-db.sh m03l02-db
docker build -q -f module-02/03-entrypoint-and-cmd/Dockerfile -t brightlane/pricing:0.3 app
docker build -q -f module-03/02-signals/Dockerfile.wrapper --build-context scripts=module-03/02-signals -t brightlane/pricing:0.3-wrapper app

step "1. An entrypoint script that starts the worker"
stop_mid_job --stop-timeout 10 brightlane/pricing:0.3-wrapper --pace 0.1
docker run --rm --entrypoint cat brightlane/pricing:0.3-wrapper /usr/local/bin/start-worker.sh | tail -1

step "2. Who is PID 1?"
docker run -d --name m03l02-look --network container:m03l02-db -e PRICING_DATABASE_URL=$DB_URL brightlane/pricing:0.3-wrapper > /dev/null; sleep 1
docker run --rm --pid=container:m03l02-look alpine:3.24.3 ps -o pid,args | head -3
docker rm -f m03l02-look > /dev/null

step "3. The worker as PID 1, without a SIGTERM handler"
stop_mid_job --stop-timeout 10 brightlane/pricing:0.3 worker --pace 0.1 --no-graceful

step "4. The same, with an init process as PID 1 (--init)"
stop_mid_job --stop-timeout 10 --init brightlane/pricing:0.3 worker --pace 0.1 --no-graceful

step "5. The worker's own SIGTERM handler"
stop_mid_job --stop-timeout 10 brightlane/pricing:0.3 worker --pace 0.1

step "6. Break it: the same worker with Docker Desktop's default grace period"
stop_mid_job brightlane/pricing:0.3 worker --pace 0.1

step "Clean up"
docker rm -f -v m03l02-db
docker image rm brightlane/pricing:0.3-wrapper
