#!/usr/bin/env bash
# Exercise 6.2, a possible solution: the three fixes, one per fault (run after start/plant.sh).
set -eu

# Fault 1, found at rung 1 (the name): the API container had exited, and a stopped container has no
# DNS entry. Its logs said why: "invalid choice: 'apii'". Start it with the right command.
docker rm -f m06x2-api > /dev/null
docker run -d --name m06x2-api --network name=m06x2-back --network name=m06x2-front,alias=pricing-api \
  --env-file .lab/m06x2/api.env brightlane/pricing:0.5 api > /dev/null

# Fault 2, found at rung 4 (the port): the proxy sent requests to port 8080; the API listens on 8000.
sed 's|http://pricing-api:8080|http://pricing-api:8000|' .lab/m06x2/nginx.conf > .lab/m06x2/nginx.conf.new
mv .lab/m06x2/nginx.conf.new .lab/m06x2/nginx.conf
docker restart m06x2-proxy > /dev/null

# Fault 3, found at rung 6 (the app's logs): "failed to resolve host 'pricing-db'". The database
# runs on the back network without that alias. Give it the alias; no restart needed.
docker network disconnect m06x2-back m06x2-db
docker network connect --alias pricing-db m06x2-back m06x2-db

sleep 4
curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8762/quotes -H 'content-type: application/json' \
  -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
