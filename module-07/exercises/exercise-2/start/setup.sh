#!/usr/bin/env bash
# Exercise 7.2: the pricing database with this week's changes (run from the repository root).
set -u
docker rm -f -v m07x2-db > /dev/null 2>&1
docker volume rm m07x2-pgdata > /dev/null 2>&1
mkdir -p .lab/m07x2
bash tools/pricing-db.sh m07x2-db -v m07x2-pgdata:/var/lib/postgresql
docker exec -i m07x2-db psql -U pricing -d pricing -q -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO tariffs SELECT 'tar-site-N03-3', site_id, 0.52, idle_fee_per_min, DATE '2026-11-01'
  FROM tariffs WHERE tariff_id = 'tar-site-N03-2';
INSERT INTO quotes (site_id, energy_kwh, idle_minutes, tariff_id, amount_eur)
  SELECT 'site-N03', 10 + i, i % 7, 'tar-site-N03-2', round((10 + i) * 0.49 + (i % 7) * 0.10, 2)
  FROM generate_series(1, 25) AS i;
SQL
docker exec m07x2-db psql -U pricing -d pricing -tAc "SELECT (SELECT count(*) FROM session_charges) || ' charges, ' || (SELECT count(*) FROM tariffs) || ' tariffs, ' || (SELECT count(*) FROM quotes) || ' quotes'"
