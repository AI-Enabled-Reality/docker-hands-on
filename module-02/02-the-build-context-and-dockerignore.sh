#!/usr/bin/env bash
# Lesson 2.2, The build context and .dockerignore: the practical as a shell session.
# Run it whole from the repository root:  bash module-02/02-the-build-context-and-dockerignore.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. Make app/ look like a developer's folder: a local venv and a .env"
made_venv=no; made_env=no
if [ ! -e app/.venv ]; then python3 -m venv app/.venv && app/.venv/bin/pip install -q duckdb==2.0.0 && made_venv=yes; fi
if [ ! -e app/.env ]; then echo "PRICING_ADMIN_TOKEN=bl-adm-7f3a19c2e5d84b06" > app/.env && made_env=yes; fi
du -sh app app/.venv app/src
cat app/.env

step "2. Build with no ignore file, and watch the context"
docker build --progress=plain -f module-02/01-a-dockerfile/Dockerfile -t brightlane/pricing:0.2-noignore app 2>&1 | grep -E "load (.dockerignore|build context)|transferring context"

step "3. What came along"
docker run --rm brightlane/pricing:0.2-noignore ls -a /app
docker run --rm brightlane/pricing:0.2-noignore cat /app/.env
docker image ls --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" brightlane/pricing

step "4. Break it: run the Python from the copied venv"
docker run --rm brightlane/pricing:0.2-noignore /app/.venv/bin/python --version
docker run --rm brightlane/pricing:0.2-noignore ls -l /app/.venv/bin/ | grep python

step "5. Add an ignore file next to the Dockerfile and build again"
grep -vE "^#|^$" module-02/02-build-context/Dockerfile.dockerignore
docker build --progress=plain -f module-02/02-build-context/Dockerfile -t brightlane/pricing:0.2 app 2>&1 | grep -E "load (.dockerignore|build context)|transferring context"
docker run --rm brightlane/pricing:0.2 ls -a /app
docker image ls --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" brightlane/pricing

step "Clean up"
docker image rm brightlane/pricing:0.2-noignore
[ "$made_venv" = yes ] && rm -rf app/.venv
[ "$made_env" = yes ] && rm -f app/.env
ls -a app
