#!/usr/bin/env bash
# Exercise 8.1: the stack as docker commands (run from the repository root). Your compose.yaml replaces this.
# Remove it again with:
#   docker rm -f -v m08x1-proxy m08x1-api m08x1-db; docker volume rm m08x1-pgdata; docker network rm m08x1-net
set -eu
docker network create m08x1-net
docker volume create m08x1-pgdata
bash tools/pricing-db.sh m08x1-db --network name=m08x1-net,alias=db -v m08x1-pgdata:/var/lib/postgresql
docker run -d --name m08x1-api --network name=m08x1-net,alias=pricing-api \
  -e PRICING_DATABASE_URL=postgresql://pricing@db:5432/pricing \
  -e PRICING_DATABASE_PASSWORD=pricing-lab-only \
  brightlane/pricing:0.8
docker run -d --name m08x1-proxy --network m08x1-net -p 127.0.0.1:8781:8080 \
  -v "$PWD/module-08/exercises/exercise-1/start/nginx.conf:/etc/nginx/nginx.conf:ro" \
  nginx:1.30.6-alpine
