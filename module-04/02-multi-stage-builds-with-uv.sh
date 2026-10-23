#!/usr/bin/env bash
# Lesson 4.2, Multi-stage builds with uv: the practical as a shell session.
# Run it whole from the repository root:  bash module-04/02-multi-stage-builds-with-uv.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
TIMEFORMAT='build took %R s'

step "1. Build the multi-stage image"
time docker build --progress=plain -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > .lab/build.log 2>&1
grep -E "uv sync|Resolved|Prepared|Installed|Downloading duckdb" .lab/build.log | grep -v "^#[0-9]* \[" | sed -E 's/^#[0-9]+ [0-9.]+ //' | head -8

step "2. What the runtime image holds, and what it doesn't"
docker image ls --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" brightlane/pricing | grep -E "TAG|:0\.[45] "
docker image history --format "table {{.CreatedBy}}\t{{.Size}}" brightlane/pricing:0.5 | head -7
docker run --rm --entrypoint sh brightlane/pricing:0.5 -c 'command -v uv || echo "no uv"; ls -A /app; ls /app/.venv/bin | head -5'

step "3. It runs"
docker run --rm brightlane/pricing:0.5 version

step "4. A code change rebuilds only the last step"
mkdir -p .lab && rm -rf .lab/m04-app && cp -R app .lab/m04-app
time docker build --progress=plain -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 .lab/m04-app > .lab/build.log 2>&1
echo "# Changed on $(date)" >> .lab/m04-app/src/pricing/quotes.py
time docker build --progress=plain -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 .lab/m04-app > .lab/build.log 2>&1
grep -E "^#[0-9]+ (CACHED|\[(build|stage-1) [0-9]/[0-9]\])" .lab/build.log | grep -v "FROM\|--from=ghcr" | sed -E 's/^#([0-9]+) /\1 /' | awk '{ if ($2 == "CACHED") c[$1] = 1; else if (!($1 in s)) { s[$1] = substr($0, index($0, $2), 60); o[++n] = $1 } } END { for (i = 1; i <= n; i++) printf "  %-7s %s\n", (c[o[i]] ? "CACHED" : "ran"), s[o[i]] }'

step "5. A change to pyproject.toml reruns the dependency step, from uv's cache"
sed -i.bak 's/^description = .*/description = "Brightlane pricing: API and statement worker."/' .lab/m04-app/pyproject.toml
time docker build --progress=plain -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 .lab/m04-app > .lab/build.log 2>&1
grep -E "Prepared|Installed|Downloading" .lab/build.log | sed -E 's/^#[0-9]+ [0-9.]+ //' | head -4

step "6. Break it: an Alpine runtime stage"
grep "^FROM" module-04/02-multi-stage/Dockerfile.alpine-runtime
docker build -q -f module-04/02-multi-stage/Dockerfile.alpine-runtime -t brightlane/pricing:0.5-alpine-runtime app
docker run --rm brightlane/pricing:0.5-alpine-runtime version 2>&1 | tail -1
docker run --rm --entrypoint sh brightlane/pricing:0.5-alpine-runtime -c 'ldd /app/.venv/lib/python3.14/site-packages/pydantic_core/_pydantic_core*.so 2>&1 | head -2'

step "Clean up"
docker image rm brightlane/pricing:0.5-alpine-runtime
rm -rf .lab/m04-app .lab/build.log
