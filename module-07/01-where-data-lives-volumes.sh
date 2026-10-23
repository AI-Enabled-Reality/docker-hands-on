#!/usr/bin/env bash
# Lesson 7.1, Where data lives: volumes. The practical as a shell session.
# Run it whole from the repository root:  bash module-07/01-where-data-lives-volumes.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
sql() { docker exec m07l01-db psql -U pricing -d pricing -tAc "$1"; }
n03() { sql "SELECT tariff_id || '  ' || price_per_kwh || ' from ' || valid_from FROM tariffs WHERE site_id = 'site-N03' ORDER BY valid_from"; }
# Monday's change: finance raises site-N03 to 0.52 EUR/kWh from 1 November.
monday() { sql "INSERT INTO tariffs SELECT 'tar-site-N03-3', site_id, 0.52, idle_fee_per_min, DATE '2026-11-01' FROM tariffs WHERE tariff_id = 'tar-site-N03-2'" > /dev/null; }
wait_db() { for i in $(seq 1 60); do docker exec "$1" pg_isready -U pricing -q 2>/dev/null && return; sleep 1; done; }
docker rm -f -v m07l01-db m07l01-old m07l01-rescue > /dev/null 2>&1
docker volume rm m07l01-pgdata m07l01-html m07l01-old > /dev/null 2>&1

step "0. The pricing database, as in every lesson so far"
bash tools/pricing-db.sh m07l01-db
docker inspect -f '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{end}}' m07l01-db
old_volume=$(docker inspect -f '{{range .Mounts}}{{.Name}}{{end}}' m07l01-db)

step "1. Monday: a tariff change"
monday
n03

step "2. Break it: recreate the container for an upgrade"
docker rm -f m07l01-db > /dev/null
bash tools/pricing-db.sh m07l01-db
n03

step "3. Monday's data isn't gone yet: a dangling volume"
docker volume ls --filter dangling=true --format '{{.Name}}' | grep "^$old_volume$" | cut -c1-12
docker run -d --name m07l01-rescue -v $old_volume:/var/lib/postgresql postgres:18.6-trixie > /dev/null
wait_db m07l01-rescue
docker exec m07l01-rescue psql -U pricing -d pricing -tAc "SELECT tariff_id FROM tariffs WHERE site_id = 'site-N03' ORDER BY 1"
docker rm -f m07l01-rescue > /dev/null
docker volume rm $old_volume > /dev/null && echo "removed ${old_volume:0:12}: now it is gone"

step "4. A named volume"
docker rm -f -v m07l01-db > /dev/null
docker volume create m07l01-pgdata
bash tools/pricing-db.sh m07l01-db -v m07l01-pgdata:/var/lib/postgresql
monday
docker rm -f m07l01-db > /dev/null
docker run -d --name m07l01-db -e POSTGRES_USER=pricing -e POSTGRES_PASSWORD=pricing-lab-only \
  -v m07l01-pgdata:/var/lib/postgresql postgres:18.6-trixie > /dev/null
wait_db m07l01-db
n03

step "5. Where the volume is"
docker volume inspect m07l01-pgdata --format '{{.Driver}} {{.Mountpoint}}'
ls /var/lib/docker/volumes 2>&1
docker run --rm -v m07l01-pgdata:/v:ro busybox:1.38.0 sh -c 'ls /v; ls /v/18/docker | head -5; du -sh /v'

step "6. First-mount copy-up"
docker volume create m07l01-html > /dev/null
docker run --rm -v m07l01-html:/usr/share/nginx/html nginx:1.30.6-alpine ls /usr/share/nginx/html
docker run --rm -v m07l01-html:/data busybox:1.38.0 ls /data
mkdir -p .lab/m07l01/empty
docker run --rm -v "$PWD/.lab/m07l01/empty:/usr/share/nginx/html" nginx:1.30.6-alpine ls /usr/share/nginx/html; echo "(nothing: a bind mount hides what's there)"

step "7. Break it: PostgreSQL 17's mount path on PostgreSQL 18"
docker run -d --name m07l01-old -e POSTGRES_PASSWORD=pricing-lab-only -v m07l01-old:/var/lib/postgresql/data postgres:18.6-trixie > /dev/null
sleep 4
docker ps -a --filter name=m07l01-old --format '{{.Names}}: {{.Status}}'
docker logs m07l01-old 2>&1 | sed -n '1p;8,9p'

step "Clean up"
docker rm -f -v m07l01-db m07l01-old
docker volume rm m07l01-pgdata m07l01-html m07l01-old
rm -rf .lab/m07l01
