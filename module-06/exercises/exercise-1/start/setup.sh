#!/usr/bin/env bash
# Exercise 6.1: a fresh pricing database, m06x1-db, on Docker's default network (run from the repository root).
set -u
docker rm -f m06x1-api > /dev/null 2>&1
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
bash tools/pricing-db.sh m06x1-db
