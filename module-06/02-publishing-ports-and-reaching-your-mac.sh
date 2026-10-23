#!/usr/bin/env bash
# Lesson 6.2, Publishing ports and reaching your Mac: the practical as a shell session.
# Run it whole from the repository root:  bash module-06/02-publishing-ports-and-reaching-your-mac.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
docker rm -f m06l02-api m06l02-open m06l02-second m06l02-random m06l02-public m06l02-private m06l02-host > /dev/null 2>&1
docker network rm m06l02-net > /dev/null 2>&1
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null

step "1. Publish on your Mac's loopback address"
docker run -d --name m06l02-api -p 127.0.0.1:8701:8000 brightlane/pricing:0.5 > /dev/null
sleep 2
docker port m06l02-api
curl -s http://127.0.0.1:8701/version; echo
lsof -nP -iTCP:8701 -sTCP:LISTEN 2>/dev/null | awk '{print $1, $9, $10}'

step "2. Publish on every interface"
docker run -d --name m06l02-open -p 8702:8000 brightlane/pricing:0.5 > /dev/null
sleep 2
docker port m06l02-open
lsof -nP -iTCP:8702 -sTCP:LISTEN 2>/dev/null | awk 'NR > 1 {print $1, $9, $10}'
lan=$(ipconfig getifaddr "$(route -n get default | awk '/interface:/ {print $2}')")
for port in 8701 8702; do
  printf "port %s from your Mac's network address: " $port
  curl -s -m 3 http://$lan:$port/health/live || printf "no answer"; echo
done

step "3. -P: every EXPOSEd port, on a random port, on every interface"
docker image inspect --format '{{json .Config.ExposedPorts}}' brightlane/pricing:0.5
docker run -d --name m06l02-random -P brightlane/pricing:0.5 > /dev/null
docker port m06l02-random

step "4. Break it: a second container on the same host port"
docker run -d --name m06l02-second -p 127.0.0.1:8701:8000 brightlane/pricing:0.5
docker ps -a --filter name=m06l02-second --format '{{.Names}}: {{.Status}}'

step "5. Published and unpublished ports, seen from another network"
docker network create m06l02-net > /dev/null
docker run -d --name m06l02-public --network m06l02-net -p 127.0.0.1:8704:8000 brightlane/pricing:0.5 > /dev/null
docker run -d --name m06l02-private --network m06l02-net brightlane/pricing:0.5 > /dev/null
sleep 2
for name in m06l02-public m06l02-private; do
  ip=$(docker inspect -f '{{index .NetworkSettings.Networks "m06l02-net" "IPAddress"}}' $name)
  printf "%s (%s:8000) from the default bridge: " $name $ip
  docker run --rm busybox:1.38.0 wget -qO- -T 3 http://$ip:8000/health/live 2>&1; echo
done

step "6. From a container to your Mac: host.docker.internal"
mkdir -p .lab/m06l02 && echo "bl-rb-4c1d9e7a52f08b36" > .lab/m06l02/rulebook-token.txt
python3 tools/rulebook_server.py --token-file .lab/m06l02/rulebook-token.txt > .lab/m06l02/rulebook-server.log 2>&1 &
server=$!; disown
sleep 1
docker run --rm --entrypoint getent brightlane/pricing:0.5 ahostsv4 host.docker.internal | head -1
docker run --rm busybox:1.38.0 wget -qO- -T 3 http://host.docker.internal:8799/rulebook.json 2>&1; echo
docker run --rm busybox:1.38.0 wget -qO- -T 3 --header "Authorization: Bearer $(cat .lab/m06l02/rulebook-token.txt)" http://host.docker.internal:8799/rulebook.json | cut -c1-70
kill $server

step "7. Host networking: the VM's network, not your Mac's"
docker run --rm --network host busybox:1.38.0 sh -c 'ip -4 -o addr show | awk "{print \$2, \$4}"' | grep -E "^(lo|eth0) "
docker run -d --name m06l02-host --network host brightlane/pricing:0.5 api --port 8703 > /dev/null
sleep 3
printf "127.0.0.1:8703 from your Mac: "; curl -s -m 3 http://127.0.0.1:8703/health/live || printf "no answer"; echo
printf "127.0.0.1:8703 from the VM: "; docker run --rm --network host busybox:1.38.0 wget -qO- -T 3 http://127.0.0.1:8703/health/live; echo

step "Clean up"
docker rm -f m06l02-api m06l02-open m06l02-second m06l02-random m06l02-public m06l02-private m06l02-host
docker network rm m06l02-net
rm -rf .lab/m06l02
