#!/usr/bin/env bash
# Creates three containers that stopped for three different reasons (run from the repository root).
# Don't read this file before you've done the exercise: the point is to find out from Docker.
set -u
docker rm -f m03x2-a m03x2-b m03x2-c >/dev/null 2>&1
docker build -q -f module-02/03-entrypoint-and-cmd/Dockerfile -t brightlane/pricing:0.3 app >/dev/null
docker run --name m03x2-a --memory 32m --memory-swap 32m python:3.14.9-slim-trixie \
  python -c "rows = [bytes(1000) for _ in range(200_000)]" >/dev/null 2>&1
docker run --name m03x2-b python:3.14.9-slim-trixie pricing worker >/dev/null 2>&1
docker run --name m03x2-c brightlane/pricing:0.3 worker >/dev/null 2>&1
docker ps -a --filter name=m03x2 --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
