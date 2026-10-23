#!/usr/bin/env bash
# Exercise 6.1: start the pricing API against m06x1-db (run from the repository root).
# This is how it was done before module 6. It works today; it breaks after the next restart.
set -eu
db_ip=$(docker inspect -f '{{.NetworkSettings.Networks.bridge.IPAddress}}' m06x1-db)
docker rm -f m06x1-api > /dev/null 2>&1 || true
docker run -d --name m06x1-api -p 8761:8000 \
  -e PRICING_DATABASE_URL=postgresql://pricing@$db_ip:5432/pricing \
  -e PRICING_DATABASE_PASSWORD=pricing-lab-only brightlane/pricing:0.5
