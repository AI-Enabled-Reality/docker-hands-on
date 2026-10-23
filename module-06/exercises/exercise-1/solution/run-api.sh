#!/usr/bin/env bash
# Exercise 6.1, a possible solution: a network of its own, the database by an alias, loopback only.
set -eu
docker network inspect m06x1-net > /dev/null 2>&1 || docker network create m06x1-net
docker network connect --alias pricing-db m06x1-net m06x1-db 2> /dev/null || true
docker rm -f m06x1-api > /dev/null 2>&1 || true
docker run -d --name m06x1-api --network m06x1-net -p 127.0.0.1:8761:8000 \
  -e PRICING_DATABASE_URL=postgresql://pricing@pricing-db:5432/pricing \
  -e PRICING_DATABASE_PASSWORD=pricing-lab-only brightlane/pricing:0.5
