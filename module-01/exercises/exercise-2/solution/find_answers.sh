#!/usr/bin/env bash
# One way to find every answer for exercise 1.2 (run from the repository root after setup.sh).
set -eu
docker ps -s --filter name=m01x2 --format "table {{.Names}}\t{{.Size}}"
docker diff m01x2-trim | grep -E "ensurepip$"
docker image ls python:3.14.9-slim-trixie
