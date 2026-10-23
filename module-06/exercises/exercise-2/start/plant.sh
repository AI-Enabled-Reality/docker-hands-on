#!/usr/bin/env bash
# Exercise 6.2: deploys the pricing stack with three faults (run from the repository root).
# Don't read this before you've done the exercise: find the faults from the outside.
set -u
docker rm -f -v m06x2-proxy m06x2-api m06x2-db > /dev/null 2>&1
docker network rm m06x2-front m06x2-back > /dev/null 2>&1
mkdir -p .lab/m06x2
cp module-06/exercises/exercise-2/start/nginx.conf module-06/exercises/exercise-2/start/api.env .lab/m06x2/
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
docker pull -q nginx:1.30.6-alpine > /dev/null

docker network create m06x2-back > /dev/null
docker network create m06x2-front > /dev/null
bash tools/pricing-db.sh m06x2-db --network m06x2-back
docker run -d --name m06x2-api --network name=m06x2-back --network name=m06x2-front,alias=pricing-api \
  --env-file .lab/m06x2/api.env brightlane/pricing:0.5 apii > /dev/null
docker run -d --name m06x2-proxy --network m06x2-front -p 127.0.0.1:8762:8080 \
  -v "$PWD/.lab/m06x2/nginx.conf:/etc/nginx/nginx.conf:ro" nginx:1.30.6-alpine > /dev/null
sleep 3
curl -s -o /dev/null -w "The proxy answers: HTTP %{http_code}\n" http://127.0.0.1:8762/health/ready
