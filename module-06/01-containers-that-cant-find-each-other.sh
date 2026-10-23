#!/usr/bin/env bash
# Lesson 6.1, Containers that can't find each other: the practical as a shell session.
# Run it whole from the repository root:  bash module-06/01-containers-that-cant-find-each-other.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
# Ask the API, from inside its container, whether it can serve: 200 with the database, 503 without.
ready() {
  docker exec m06l01-api python -c "import urllib.request, urllib.error
try:
    r = urllib.request.urlopen('http://127.0.0.1:8000/health/ready'); print(r.status, r.read().decode())
except urllib.error.HTTPError as e:
    print(e.code, e.read().decode())"
}
wait_ready() {
  for i in $(seq 1 30); do
    ready 2>/dev/null | grep -q "^200" && { echo "ready after ${i} s"; return; }
    sleep 1
  done
  echo "not ready after 30 s"
}

step "0. The pricing database, on Docker's default network"
docker rm -f m06l01-api > /dev/null 2>&1
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
bash tools/pricing-db.sh m06l01-db

step "1. Break it: the API looks for the database by name"
docker run -d --name m06l01-api \
  -e PRICING_DATABASE_URL=postgresql://pricing@m06l01-db:5432/pricing \
  -e PRICING_DATABASE_PASSWORD=pricing-lab-only brightlane/pricing:0.5
sleep 4
ready
docker logs m06l01-api 2>&1 | grep -m1 "failed to resolve" | cut -d' ' -f3-
docker exec m06l01-api getent hosts m06l01-db; echo "getent: exit code $?"
docker exec m06l01-api grep nameserver /etc/resolv.conf

step "2. The workaround: the database's IP address"
db_ip=$(docker inspect -f '{{.NetworkSettings.Networks.bridge.IPAddress}}' m06l01-db)
echo "m06l01-db is $db_ip"
docker rm -f m06l01-api > /dev/null
docker run -d --name m06l01-api \
  -e PRICING_DATABASE_URL=postgresql://pricing@$db_ip:5432/pricing \
  -e PRICING_DATABASE_PASSWORD=pricing-lab-only brightlane/pricing:0.5 > /dev/null
sleep 3
ready

step "3. Break it: restart both, in the other order"
docker stop m06l01-db m06l01-api > /dev/null
docker start m06l01-api > /dev/null; docker start m06l01-db > /dev/null
docker inspect -f '{{.Name}} {{.NetworkSettings.Networks.bridge.IPAddress}}' m06l01-db m06l01-api
sleep 5
ready
docker logs m06l01-api 2>&1 | grep "error connecting" | tail -1 | cut -d' ' -f3-

step "4. A network of your own"
docker network create m06l01-net
docker network inspect m06l01-net --format '{{.Driver}} {{range .IPAM.Config}}{{.Subnet}} gateway {{.Gateway}}{{end}}'
docker network connect --alias pricing-db m06l01-net m06l01-db
docker inspect -f '{{range $name, $n := .NetworkSettings.Networks}}{{$name}}={{$n.IPAddress}} {{end}}' m06l01-db

step "5. The API on that network, finding the database by its alias"
docker rm -f m06l01-api > /dev/null
docker run -d --name m06l01-api --network m06l01-net \
  -e PRICING_DATABASE_URL=postgresql://pricing@pricing-db:5432/pricing \
  -e PRICING_DATABASE_PASSWORD=pricing-lab-only brightlane/pricing:0.5 > /dev/null
sleep 3
ready
docker exec m06l01-api getent hosts pricing-db m06l01-db
docker exec m06l01-api grep nameserver /etc/resolv.conf

step "6. Restart both, in the other order, again"
docker stop m06l01-db m06l01-api > /dev/null
docker start m06l01-api > /dev/null; docker start m06l01-db > /dev/null
wait_ready
ready

step "7. Who can reach whom"
docker network inspect m06l01-net --format '{{range .Containers}}{{.Name}} {{.IPv4Address}}{{println}}{{end}}'
api_ip=$(docker inspect -f '{{index .NetworkSettings.Networks "m06l01-net" "IPAddress"}}' m06l01-api)
echo "from m06l01-net, by name:"
docker run --rm --network m06l01-net busybox:1.38.0 wget -qO- -T 3 http://m06l01-api:8000/health/live; echo
echo "from the default bridge, by IP ($api_ip):"
docker run --rm busybox:1.38.0 wget -qO- -T 3 http://$api_ip:8000/health/live; echo

step "Clean up"
docker rm -f -v m06l01-api m06l01-db
docker network rm m06l01-net
