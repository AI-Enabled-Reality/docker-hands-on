#!/usr/bin/env bash
# Exercise 7.2, a possible solution: back up with pg_dump, then (after wreck.sh) restore over the damage.
# Run the two halves at the right moments:  bash restore.sh backup  /  bash restore.sh restore
set -eu
case "${1:-}" in
  backup)
    docker exec m07x2-db pg_dump -U pricing -Fc pricing > .lab/m07x2/pricing.dump
    ls -lh .lab/m07x2/pricing.dump | awk '{print $5, $9}'
    ;;
  restore)
    # --clean drops each object the dump contains before recreating it; --if-exists keeps that quiet for
    # objects the accident already removed (the quotes table).
    docker exec -i m07x2-db pg_restore -U pricing -d pricing --clean --if-exists < .lab/m07x2/pricing.dump
    docker exec m07x2-db psql -U pricing -d pricing -tAc "SELECT (SELECT count(*) FROM session_charges) || ' charges, ' || (SELECT count(*) FROM tariffs) || ' tariffs, ' || (SELECT count(*) FROM quotes) || ' quotes'"
    ;;
  *) echo "usage: bash restore.sh backup|restore"; exit 2 ;;
esac
