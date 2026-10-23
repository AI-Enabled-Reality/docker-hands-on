#!/usr/bin/env bash
# Lesson 6.3, Debugging a container that can't connect: the practical as a shell session.
# Run it whole from the repository root:  bash module-06/03-debugging-a-container-that-cant-connect.sh
# or copy the commands one step at a time.
set -u
step() { printf '\n=== %s\n' "$*"; }
# The proxy's last error, without nginx's timestamp and process numbers.
proxy_error() { docker logs m06l03-proxy 2>&1 >/dev/null | grep "\[error\]" | tail -1 | sed -E 's/^.*\[error\] [0-9#]+: \*[0-9]+ //' | cut -d, -f1,5; }
# Start the API again from its settings file, on both networks, as pricing-api on the front one.
start_api() {
  docker rm -f m06l03-api > /dev/null 2>&1
  docker run -d --name m06l03-api --network name=m06l03-back --network name=m06l03-front,alias=pricing-api \
    --env-file .lab/m06l03/api.env brightlane/pricing:0.5 > /dev/null
  sleep 4
}

step "0. Go-live morning: the stack as it was deployed"
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
bash module-06/03-debugging/go-live.sh

step "1. The symptom"
curl -s -i http://127.0.0.1:8700/health/ready | head -1
proxy_error

step "2. Rung 1, the name: can the proxy resolve pricing-api?"
docker exec m06l03-proxy getent hosts pricing-api; echo "getent: exit code $?"

step "3. Rung 2, the network: are they on the same one?"
docker inspect -f '{{.Name}}: {{range $net, $_ := .NetworkSettings.Networks}}{{$net}} {{end}}' m06l03-proxy m06l03-api m06l03-db
docker network connect --alias pricing-api m06l03-front m06l03-api
curl -s -i http://127.0.0.1:8700/health/ready | head -1
proxy_error

step "4. Rung 3, the IP: does the name lead to the API?"
docker exec m06l03-proxy getent hosts pricing-api
docker inspect -f '{{index .NetworkSettings.Networks "m06l03-front" "IPAddress"}}' m06l03-api

step "5. Rung 4, the port: does anything answer on 8000?"
docker inspect -f '{{json .Config.ExposedPorts}} {{json .Config.Cmd}}' m06l03-api
docker run --rm --network m06l03-front busybox:1.38.0 wget -qO- -T 3 http://pricing-api:8000/health/live

step "6. Rung 5, the listening address: what is the API bound to?"
docker run --rm --network container:m06l03-api busybox:1.38.0 netstat -tln
docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' m06l03-api | grep PRICING_HOST
grep -v '^PRICING_HOST=' .lab/m06l03/api.env > .lab/m06l03/api.env.new && mv .lab/m06l03/api.env.new .lab/m06l03/api.env
start_api
curl -s -i http://127.0.0.1:8700/health/ready | sed -n '1p;$p'; echo

step "7. Rung 6, the app's logs"
docker logs m06l03-api 2>&1 | grep "error connecting" | tail -1 | cut -d' ' -f3-
docker port m06l03-db
sed 's/@pricing-db:5433/@pricing-db:5432/' .lab/m06l03/api.env > .lab/m06l03/api.env.new && mv .lab/m06l03/api.env.new .lab/m06l03/api.env
start_api
curl -s -w '  (HTTP %{http_code})\n' http://127.0.0.1:8700/health/ready
curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
  -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'

step "8. What the proxy saw, request by request"
docker logs m06l03-proxy 2>/dev/null | awk '$6 ~ /"(GET|POST)/ {print $6, $7, $9}' | tr -d '"'

step "Clean up"
docker rm -f -v m06l03-proxy m06l03-api m06l03-db
docker network rm m06l03-front m06l03-back
rm -rf .lab/m06l03
