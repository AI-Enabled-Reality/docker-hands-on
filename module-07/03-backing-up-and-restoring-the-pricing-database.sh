#!/usr/bin/env bash
# Lesson 7.3, Backing up and restoring the pricing database: the practical as a shell session.
# Run it whole from the repository root:  bash module-07/03-backing-up-and-restoring-the-pricing-database.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
TIMEFORMAT='took %R s'
B=.lab/m07l03
# What a restore must bring back: every charge, every tariff, and Monday's change.
count() {
  docker exec "$1" psql -U pricing -d pricing -tAc "SELECT (SELECT count(*) FROM session_charges) || ' charges, '
    || (SELECT count(*) FROM tariffs) || ' tariffs, site-N03 from 1 November: '
    || coalesce((SELECT price_per_kwh::text FROM tariffs WHERE tariff_id = 'tar-site-N03-3'), 'missing')"
}
wait_db() { for i in $(seq 1 60); do docker exec "$1" pg_isready -U pricing -q 2>/dev/null && return; sleep 1; done; echo "$1 isn't ready"; }
# A new database runs a temporary server while it initializes; wait for the real one.
wait_init() { for i in $(seq 1 60); do docker logs "$1" 2>&1 | grep -q "init process complete" && break; sleep 1; done; wait_db "$1"; }
docker rm -f -v m07l03-db m07l03-from-dump m07l03-from-archive > /dev/null 2>&1
docker volume rm m07l03-pgdata m07l03-from-dump m07l03-from-archive > /dev/null 2>&1
rm -rf $B && mkdir -p $B

step "0. The database to protect, on a named volume, with Monday's change"
bash tools/pricing-db.sh m07l03-db -v m07l03-pgdata:/var/lib/postgresql
docker exec m07l03-db psql -U pricing -d pricing -qc "INSERT INTO tariffs SELECT 'tar-site-N03-3', site_id, 0.52, idle_fee_per_min, DATE '2026-11-01' FROM tariffs WHERE tariff_id = 'tar-site-N03-2'"
count m07l03-db

step "1. A logical backup: pg_dump, while the database runs"
time docker exec m07l03-db pg_dump -U pricing -Fc pricing > $B/pricing.dump
ls -lh $B/pricing.dump | awk '{print $5, $9}'
docker exec -i m07l03-db pg_restore --list < $B/pricing.dump | grep "TABLE DATA" | awk '{print $6, $7}'

step "2. A cold copy of the volume: stop, archive, start"
docker stop m07l03-db > /dev/null
time docker run --rm -v m07l03-pgdata:/data:ro -v "$PWD/$B:/backup" busybox:1.38.0 tar -czf /backup/pgdata.tar.gz -C /data .
docker start m07l03-db > /dev/null
ls -lh $B/pgdata.tar.gz | awk '{print $5, $9}'
tar -tzvf $B/pgdata.tar.gz --numeric-owner | grep -E " \./18/docker/(PG_VERSION|postgresql.conf)$" | awk '{print $1, $3, $4, $NF}'

step "3. Restore the dump into a new, empty database"
docker run -d --name m07l03-from-dump -e POSTGRES_USER=pricing -e POSTGRES_PASSWORD=pricing-lab-only \
  -v m07l03-from-dump:/var/lib/postgresql postgres:18.6-trixie > /dev/null
wait_init m07l03-from-dump
time docker exec -i m07l03-from-dump pg_restore -U pricing -d pricing < $B/pricing.dump
count m07l03-from-dump

step "4. Break it: restore the archive without its owners, run PostgreSQL as its own user"
docker run --rm -v m07l03-from-archive:/data -v "$PWD/$B:/backup:ro" busybox:1.38.0 tar -xzof /backup/pgdata.tar.gz -C /data
docker run --rm -v m07l03-from-archive:/data busybox:1.38.0 stat -c '%u:%g %A %n' /data/18/docker
docker run -d --name m07l03-from-archive --user postgres -v m07l03-from-archive:/var/lib/postgresql postgres:18.6-trixie > /dev/null
sleep 4
docker ps -a --filter name=m07l03-from-archive --format '{{.Names}}: {{.Status}}'
docker logs m07l03-from-archive 2>&1 | grep -v '^$' | head -2

step "5. Restore it again, keeping the owners"
docker rm -f -v m07l03-from-archive > /dev/null; docker volume rm m07l03-from-archive > /dev/null
time docker run --rm -v m07l03-from-archive:/data -v "$PWD/$B:/backup:ro" busybox:1.38.0 tar -xzf /backup/pgdata.tar.gz -C /data
docker run --rm -v m07l03-from-archive:/data busybox:1.38.0 stat -c '%u:%g %A %n' /data/18/docker
docker run -d --name m07l03-from-archive --user postgres -v m07l03-from-archive:/var/lib/postgresql postgres:18.6-trixie > /dev/null
wait_db m07l03-from-archive
count m07l03-from-archive

step "6. The original and both restores"
for name in m07l03-db m07l03-from-dump m07l03-from-archive; do printf "%-20s %s\n" $name "$(count $name)"; done

step "Clean up"
docker rm -f -v m07l03-db m07l03-from-dump m07l03-from-archive
docker volume rm m07l03-pgdata m07l03-from-dump m07l03-from-archive
rm -rf $B
