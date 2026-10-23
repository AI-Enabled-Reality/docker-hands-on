#!/usr/bin/env bash
# Lesson 6.3: deploys the pricing stack the way it went out on go-live morning (run from the repository root).
# Don't read the details before the lesson: the point is to find what's wrong from the outside.
set -u
docker rm -f -v m06l03-proxy m06l03-api m06l03-db > /dev/null 2>&1
docker network rm m06l03-front m06l03-back > /dev/null 2>&1
mkdir -p .lab/m06l03 && cp module-06/03-debugging/api.env .lab/m06l03/api.env
docker pull -q nginx:1.30.6-alpine > /dev/null

docker network create m06l03-back > /dev/null
docker network create m06l03-front > /dev/null
bash tools/pricing-db.sh m06l03-db --network name=m06l03-back,alias=pricing-db -p 127.0.0.1:5433:5432
docker run -d --name m06l03-api --network m06l03-back --env-file .lab/m06l03/api.env \
  brightlane/pricing:0.5 > /dev/null
docker run -d --name m06l03-proxy --network m06l03-front -p 127.0.0.1:8700:8080 \
  -v "$PWD/module-06/03-debugging/nginx.conf:/etc/nginx/nginx.conf:ro" nginx:1.30.6-alpine > /dev/null
sleep 3
docker ps --filter name=m06l03 --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
