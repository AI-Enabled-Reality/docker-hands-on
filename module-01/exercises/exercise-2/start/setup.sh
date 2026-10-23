#!/usr/bin/env bash
# Creates Tomasz's two experiment containers for exercise 1.2 (run from the repository root).
set -eu
docker rm -f m01x2-export m01x2-trim >/dev/null 2>&1 || true
docker run -d --name m01x2-export python:3.14.9-slim-trixie sleep 3600 >/dev/null
docker exec m01x2-export dd if=/dev/urandom of=/srv/statement-export.bin bs=1M count=30 status=none
docker run -d --name m01x2-trim python:3.14.9-slim-trixie sleep 3600 >/dev/null
docker exec m01x2-trim rm -r /usr/local/lib/python3.14/ensurepip
docker exec m01x2-trim dd if=/dev/urandom of=/tmp/scratch.bin bs=1M count=5 status=none
echo "m01x2-export and m01x2-trim are running. Now find the answers."
