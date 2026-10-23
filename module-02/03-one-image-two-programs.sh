#!/usr/bin/env bash
# Lesson 2.3, One image, two programs: ENTRYPOINT and CMD. The practical as a shell session.
# Run it whole from the repository root:  bash module-02/03-one-image-two-programs.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. Build the image with ENTRYPOINT and CMD"
grep -E "^(ENTRYPOINT|CMD)" module-02/03-entrypoint-and-cmd/Dockerfile
docker build -q -f module-02/03-entrypoint-and-cmd/Dockerfile -t brightlane/pricing:0.3 app
docker image inspect --format 'Entrypoint={{json .Config.Entrypoint}} Cmd={{json .Config.Cmd}}' brightlane/pricing:0.3

step "2. No arguments: the API"
docker run -d --name m02l03-api -p 127.0.0.1:8701:8000 brightlane/pricing:0.3
sleep 2
curl -s http://127.0.0.1:8701/version; echo
docker logs m02l03-api 2>&1 | head -3

step "3. Arguments replace CMD: other programs from the same image"
docker run --rm brightlane/pricing:0.3 version
docker run --rm brightlane/pricing:0.3 --help
docker run --rm brightlane/pricing:0.3 worker --once
echo "exit code: $?"

step "4. Replace the entrypoint to look around"
docker run --rm --entrypoint sh brightlane/pricing:0.3 -c 'command -v pricing; head -4 "$(command -v pricing)"'

step "5. Break it: ENTRYPOINT in shell form"
docker build --progress=plain -f module-02/03-entrypoint-and-cmd/Dockerfile.shell-form -t brightlane/pricing:0.3-shell app 2>&1 | grep -A1 "warning found" | sed "s/\x1b\[[0-9;]*m//g"
docker image inspect --format 'Entrypoint={{json .Config.Entrypoint}} Cmd={{json .Config.Cmd}}' brightlane/pricing:0.3-shell
docker run -d --name m02l03-shell brightlane/pricing:0.3-shell worker --once
sleep 2
docker ps --filter name=m02l03-shell --format "{{.Names}}: {{.Status}} {{.Command}}"
docker logs m02l03-shell 2>&1 | head -2

step "Clean up"
docker rm -f m02l03-api m02l03-shell
docker image rm brightlane/pricing:0.3-shell
