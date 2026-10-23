#!/usr/bin/env bash
# Lesson 4.3, Choosing a base image: slim, alpine, distroless. The practical as a shell session.
# Run it whole from the repository root:  bash module-04/03-choosing-a-base-image.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
TIMEFORMAT='build took %R s'
mkdir -p .lab

step "1. Three variants of the same multi-stage build"
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app
time docker build -q -f module-04/03-base-images/Dockerfile.alpine-api -t brightlane/pricing:0.5-alpine-api app
time docker build -q -f module-04/03-base-images/Dockerfile.distroless -t brightlane/pricing:0.5-distroless app

step "2. Size, Python and C library of each"
docker image ls brightlane/pricing | grep -E "^IMAGE|:0\.5"
for tag in 0.5 0.5-alpine-api 0.5-distroless; do
  echo "$tag: $(docker run --rm --entrypoint python brightlane/pricing:$tag -c 'import platform; print(platform.python_version(), *platform.libc_ver())')"
done

step "3. Break it: Alpine with DuckDB"
time docker build --progress=plain -f module-04/03-base-images/Dockerfile.alpine -t brightlane/pricing:0.5-alpine app > .lab/build.log 2>&1
grep -E "Building duckdb|error: Failed|Could not find the compiler|^#[0-9]+ [0-9.]+ +gcc\.$|hint:" .lab/build.log | sed -E 's/^#[0-9]+ //; s/^[0-9.]+ //' | awk '!seen[$0]++' 

step "4. The worker on Alpine without DuckDB"
docker run --rm -e PRICING_DATABASE_URL=postgresql://pricing@db:5432/pricing brightlane/pricing:0.5-alpine-api worker --once 2>&1 | tail -1

step "5. Distroless: no shell to exec into"
docker run -d --name m04l03-distroless -p 127.0.0.1:8703:8000 brightlane/pricing:0.5-distroless
sleep 2
curl -s http://127.0.0.1:8703/version; echo
docker exec m04l03-distroless sh -c 'echo hello'
docker run --rm --pid=container:m04l03-distroless --network=container:m04l03-distroless busybox:1.38.0 sh -c 'ps -o pid,args; wget -qO- http://127.0.0.1:8000/health/live; echo'

step "Clean up"
docker rm -f m04l03-distroless
docker image rm brightlane/pricing:0.5-alpine-api brightlane/pricing:0.5-distroless
rm -f .lab/build.log
