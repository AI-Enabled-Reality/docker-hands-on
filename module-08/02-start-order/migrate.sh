#!/bin/sh
# Lesson 8.2: the one-off job that prepares the database before the API and the worker start.
# It loads the schema and the seed once, and does nothing if they're already there.
set -eu
if [ "$(psql -tAc "SELECT to_regclass('public.tariffs') IS NOT NULL")" = "t" ]; then
  echo "migrate: the schema is already in place"
else
  psql -q -v ON_ERROR_STOP=1 -f /init/01-schema.sql -f /init/02-seed.sql > /dev/null
  echo "migrate: schema and seed loaded, $(psql -tAc 'SELECT count(*) FROM session_charges') session charges"
fi
