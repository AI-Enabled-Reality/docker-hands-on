#!/usr/bin/env bash
# Lesson 7.2, Bind mounts, tmpfs and file permissions: the practical as a shell session.
# Run it whole from the repository root:  bash module-07/02-bind-mounts-tmpfs-and-file-permissions.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
sql() { docker exec m07l02-db psql -U pricing -d pricing -tAc "$1"; }
# Queue a statement for one site and day, let a worker handle it once, print how it ended.
# Usage: export_job <docker run options...> <image>
export_job() {
  sql "INSERT INTO statement_jobs (site_id, period) VALUES ('site-N03', '2026-10-15')" > /dev/null
  docker run --rm --network m07l02-net -e PRICING_DATABASE_PASSWORD=pricing-lab-only "$@" worker --once > /dev/null 2>&1
  sql "SELECT 'job ' || id || ': ' || status || coalesce(', ' || rows || ' rows', '') || coalesce(', ' || error, '') FROM statement_jobs ORDER BY id DESC LIMIT 1"
}
# Owner (uid:gid) and mode of the exports folder in a volume.
owner() { docker run --rm -v "$1":/e busybox:1.38.0 stat -c '%u:%g %A' /e/statements/site-N03 2>/dev/null || docker run --rm -v "$1":/e busybox:1.38.0 stat -c '%u:%g %A (empty)' /e; }
docker rm -f -v m07l02-db > /dev/null 2>&1
docker volume rm m07l02-exports m07l02-new m07l02-exports2 > /dev/null 2>&1
docker network rm m07l02-net > /dev/null 2>&1
rm -rf .lab/m07l02

step "0. The database, and two images that run as user 10001"
docker network create m07l02-net > /dev/null
bash tools/pricing-db.sh m07l02-db --network name=m07l02-net,alias=db
docker build -q -f module-07/02-mounts/Dockerfile.user-only -t brightlane/pricing:0.8-user app > /dev/null
docker build -q -f module-07/02-mounts/Dockerfile -t brightlane/pricing:0.8 app > /dev/null
docker run --rm --entrypoint id brightlane/pricing:0.5
docker run --rm --entrypoint id brightlane/pricing:0.8-user

step "1. The root worker writes its export to a new volume"
export_job -v m07l02-exports:/exports brightlane/pricing:0.5
owner m07l02-exports

step "2. Break it: the same volume, the worker as user 10001"
export_job -v m07l02-exports:/exports brightlane/pricing:0.8-user

step "3. Break it: a new volume, the worker as user 10001"
export_job -v m07l02-new:/exports brightlane/pricing:0.8-user
owner m07l02-new

step "4. The fix in the image: an /exports that belongs to the user"
diff module-07/02-mounts/Dockerfile.user-only module-07/02-mounts/Dockerfile | grep -E '^> (RUN| &&)'
export_job -v m07l02-exports2:/exports brightlane/pricing:0.8
owner m07l02-exports2

step "5. An existing volume keeps its owner"
export_job -v m07l02-exports:/exports brightlane/pricing:0.8
docker run --rm -v m07l02-exports:/exports busybox:1.38.0 chown -R 10001:10001 /exports
export_job -v m07l02-exports:/exports brightlane/pricing:0.8

step "6. A bind mount: a folder on your Mac"
mkdir -p .lab/m07l02/exports
export_job -v "$PWD/.lab/m07l02/exports:/exports" brightlane/pricing:0.8
docker run --rm -v "$PWD/.lab/m07l02/exports:/exports" --entrypoint ls brightlane/pricing:0.8 -ln /exports/statements/site-N03
ls .lab/m07l02/exports/statements/site-N03
f=.lab/m07l02/exports/statements/site-N03/2026-10-15.parquet
[ "$(stat -f %u $f)" = "$(id -u)" ] && echo "on your Mac, the file belongs to you"

step "7. Small files: a volume and a bind mount, timed"
test_files='import os, time
t = time.perf_counter()
for i in range(5000):
    with open(f"/t/f{i}", "w") as f: f.write("x" * 4096)
print(f"wrote 5,000 files in {time.perf_counter() - t:.2f} s")'
docker volume create m07l02-speed > /dev/null; mkdir -p .lab/m07l02/speed
printf "volume:     "; docker run --rm -v m07l02-speed:/t --entrypoint python brightlane/pricing:0.5 -c "$test_files"
printf "bind mount: "; docker run --rm -v "$PWD/.lab/m07l02/speed:/t" --entrypoint python brightlane/pricing:0.5 -c "$test_files"

step "8. A read-only bind mount for configuration"
docker run --rm -v "$PWD/module-06/03-debugging/nginx.conf:/etc/nginx/nginx.conf:ro" nginx:1.30.6-alpine \
  sh -c 'grep -c resolver /etc/nginx/nginx.conf; echo "# edited" >> /etc/nginx/nginx.conf'

step "9. tmpfs: a folder in memory"
docker run --rm --tmpfs /tmp:size=16m busybox:1.38.0 sh -c 'mount | grep " /tmp "; echo scratch > /tmp/f; ls /tmp'

step "10. Break it: a colon in the path"
mkdir -p ".lab/m07l02/run 10:30"
docker run --rm -v "$PWD/.lab/m07l02/run 10:30:/data" busybox:1.38.0 ls -ld /data
docker run --rm --mount "type=bind,source=$PWD/.lab/m07l02/run 10:30,target=/data" busybox:1.38.0 ls -ld /data

step "Clean up"
docker rm -f -v m07l02-db
docker volume rm m07l02-exports m07l02-new m07l02-exports2 m07l02-speed
docker network rm m07l02-net
rm -rf .lab/m07l02
