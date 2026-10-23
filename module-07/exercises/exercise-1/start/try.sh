#!/usr/bin/env bash
# Exercise 7.1: build your Dockerfile and run one export into a new volume (run from the repository root).
set -u
docker build -q -f module-07/exercises/exercise-1/Dockerfile -t brightlane/pricing:m07x1 app > /dev/null || exit 1
docker network inspect m07x1-net > /dev/null 2>&1 || docker network create m07x1-net > /dev/null
docker ps -q --filter name=^m07x1-db$ | grep -q . || bash tools/pricing-db.sh m07x1-db --network name=m07x1-net,alias=db
docker volume rm m07x1-try > /dev/null 2>&1
docker exec m07x1-db psql -U pricing -d pricing -qc "INSERT INTO statement_jobs (site_id, period) VALUES ('site-C03', '2026-10-15')"
echo "the image runs as: $(docker run --rm --entrypoint id brightlane/pricing:m07x1)"
docker run --rm --network m07x1-net -e PRICING_DATABASE_PASSWORD=pricing-lab-only -v m07x1-try:/exports \
  brightlane/pricing:m07x1 worker --once 2>&1 | tail -1
docker exec m07x1-db psql -U pricing -d pricing -tAc "SELECT 'job ' || id || ': ' || status || coalesce(', ' || error, '') FROM statement_jobs ORDER BY id DESC LIMIT 1"
docker volume rm m07x1-try > /dev/null
