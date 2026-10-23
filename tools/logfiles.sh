#!/usr/bin/env bash
# The log files Docker keeps for a container, with their sizes in bytes (module 11).
#   bash tools/logfiles.sh <container>
# They live in Docker's own folder, /var/lib/docker/containers/<id>/, inside Docker Desktop's VM (on a
# Linux server, on the host). A throwaway container mounts that one folder read-only and lists it.
set -eu
id=$(docker inspect -f '{{.Id}}' "$1")
docker run --rm -v "/var/lib/docker/containers/$id:/c:ro" alpine:3.24.3 \
  sh -c 'cd /c && find . -type f -name "*log*" | sort | xargs ls -ln' \
  | awk '{printf "%10s  %s\n", $5, $9}' | sed "s|$id|<id>|g; s|  \./|  |"
