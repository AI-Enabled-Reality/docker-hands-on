#!/usr/bin/env bash
# Lesson 2.1, A Dockerfile for the pricing API: the practical as a shell session.
# Run it whole from the repository root:  bash module-02/01-a-dockerfile-for-the-pricing-api.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. The Dockerfile"
grep -vE "^#|^$" module-02/01-a-dockerfile/Dockerfile

step "2. Build the image from the app/ folder"
docker build -f module-02/01-a-dockerfile/Dockerfile -t brightlane/pricing:0.1 app

step "3. What you built"
docker image ls brightlane/pricing:0.1
docker image history --format "table {{.CreatedBy}}\t{{.Size}}" brightlane/pricing:0.1 | head -8
docker image inspect --format 'Cmd={{json .Config.Cmd}} ExposedPorts={{json .Config.ExposedPorts}}' brightlane/pricing:0.1
docker image inspect --format '{{json .Config.Labels}}' brightlane/pricing:0.1

step "4. Run it and ask it questions"
docker run -d --name m02l01-api -p 127.0.0.1:8701:8000 brightlane/pricing:0.1
sleep 2
curl -s http://127.0.0.1:8701/health/live; echo
curl -s -w ' HTTP %{http_code}\n' http://127.0.0.1:8701/health/ready
docker logs m02l01-api

step "5. Break it: let Uvicorn choose the address"
docker run -d --name m02l01-local -p 127.0.0.1:8702:8000 brightlane/pricing:0.1 uvicorn pricing.api:app --port 8000
sleep 2
curl -sS http://127.0.0.1:8702/health/live; echo
docker logs m02l01-local 2>&1 | grep "Uvicorn running"
docker exec m02l01-local python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/health/live').read().decode())"

step "Clean up"
docker rm -f m02l01-api m02l01-local
