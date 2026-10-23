#!/usr/bin/env bash
# Lesson 1.1, From a VM to a container: the practical as a shell session.
# Run it whole from the repository root:  bash module-01/01-from-a-vm-to-a-container.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. Run Python 3.14.9 in a container"
docker run --rm python:3.14.9-slim-trixie python -c "import platform, sys; print(sys.version); print(platform.platform())"

step "   The second run: no pull, and how long a start takes"
time docker run --rm python:3.14.9-slim-trixie python -c "pass"

step "   The Python on your Mac, for comparison"
python3 -c "import platform, sys; print(sys.version); print(platform.platform())" || echo "(no python3 on this Mac)"

step "2. Two containers from one image"
docker run --name m01l01-first python:3.14.9-slim-trixie python -c "import socket; print('hello from', socket.gethostname())"
docker run --name m01l01-second python:3.14.9-slim-trixie python -c "import socket; print('hello from', socket.gethostname())"
docker ps -a --filter name=m01l01 --format "table {{.Names}}\t{{.ID}}\t{{.Image}}\t{{.Status}}"
docker image ls python:3.14.9-slim-trixie

step "3. What the image holds"
docker run --rm python:3.14.9-slim-trixie grep -E "^(PRETTY_NAME|VERSION_CODENAME)" /etc/os-release
docker run --rm python:3.14.9-slim-trixie pip list

step "4. Break it: a container with nothing to do"
docker run --name m01l01-repl python:3.14.9-slim-trixie
docker ps -a --filter name=m01l01-repl --format "{{.Names}}: {{.Status}}"
docker image inspect --format '{{json .Config.Cmd}}' python:3.14.9-slim-trixie
echo 'print(6 * 7)' | docker run --rm -i python:3.14.9-slim-trixie

step "Clean up"
docker rm m01l01-first m01l01-second m01l01-repl
