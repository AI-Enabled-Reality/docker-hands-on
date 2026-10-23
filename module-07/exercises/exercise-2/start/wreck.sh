#!/usr/bin/env bash
# Exercise 7.2: an afternoon of mistakes (run from the repository root, after your backup).
set -u
docker exec -i m07x2-db psql -U pricing -d pricing -q -v ON_ERROR_STOP=1 <<'SQL'
DELETE FROM session_charges WHERE site_id LIKE 'site-C%';
DELETE FROM tariffs WHERE tariff_id = 'tar-site-N03-3';
DROP TABLE quotes;
SQL
docker exec m07x2-db psql -U pricing -d pricing -tAc "SELECT (SELECT count(*) FROM session_charges) || ' charges, ' || (SELECT count(*) FROM tariffs) || ' tariffs; quotes: ' || coalesce(to_regclass('quotes')::text, 'gone')"
