#!/bin/sh
# Capstone: lesson 8.2's migration job, with migrations. It loads the schema and the seed once, then
# runs every /migrations/*.sql file in name order. Each migration must be safe to run again.
set -eu
if [ "$(psql -tAc "SELECT to_regclass('public.tariffs') IS NOT NULL")" = "t" ]; then
  echo "migrate: the schema is already in place"
else
  psql -q -v ON_ERROR_STOP=1 -f /init/01-schema.sql -f /init/02-seed.sql > /dev/null
  echo "migrate: schema and seed loaded, $(psql -tAc 'SELECT count(*) FROM session_charges') session charges"
fi
for migration in /migrations/*.sql; do
  [ -e "$migration" ] || continue
  psql -q -v ON_ERROR_STOP=1 -f "$migration" > /dev/null
  echo "migrate: applied $(basename "$migration")"
done
echo "migrate: $(psql -tAc 'SELECT count(*) FROM sites') sites"
