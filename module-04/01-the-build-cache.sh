#!/usr/bin/env bash
# Lesson 4.1, The build cache: the practical as a shell session.
# Run it whole from the repository root:  bash module-04/01-the-build-cache.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
# Build, time it, and list which steps ran and which came from the cache.
build() {
  local dockerfile=$1 tag=$2; shift 2
  local TIMEFORMAT='build took %R s'
  time docker build --progress=plain "$@" -f "$dockerfile" -t "$tag" .lab/m04-app > .lab/build.log 2>&1
  awk '/^#[0-9]+ \[[0-9]+\/[0-9]+\]/ { id = $1; sub(/^#[0-9]+ /, ""); if (!(id in step)) { step[id] = substr($0, 1, 60); order[++n] = id } }
       /^#[0-9]+ CACHED$/ { cached[$1] = 1 }
       END { for (i = 1; i <= n; i++) printf "  %-7s %s\n", (cached[order[i]] ? "CACHED" : "ran"), step[order[i]] }' .lab/build.log |
    grep -v FROM | sort -t '[' -k2,2n
}

step "0. A scratch copy of the app to change"
rm -rf .lab/m04-app && mkdir -p .lab && cp -R app .lab/m04-app
ls .lab/m04-app

step "1. Dependencies first: a first build, without any cache"
grep -vE "^#|^$" module-04/01-build-cache/Dockerfile.deps-first
build module-04/01-build-cache/Dockerfile.deps-first brightlane/pricing:0.4 --no-cache

step "2. Change one line of code, build again"
echo "# Changed on $(date)" >> .lab/m04-app/src/pricing/quotes.py
build module-04/01-build-cache/Dockerfile.deps-first brightlane/pricing:0.4

step "3. Touch a file without changing it"
touch .lab/m04-app/src/pricing/api.py
build module-04/01-build-cache/Dockerfile.deps-first brightlane/pricing:0.4

step "4. Break it: copy everything first"
grep -E "^(COPY|RUN)" module-04/01-build-cache/Dockerfile.copy-first
build module-04/01-build-cache/Dockerfile.copy-first brightlane/pricing:0.4-copy-first
echo "# Changed again on $(date)" >> .lab/m04-app/src/pricing/quotes.py
build module-04/01-build-cache/Dockerfile.copy-first brightlane/pricing:0.4-copy-first

step "Clean up"
docker image rm brightlane/pricing:0.4-copy-first
rm -rf .lab/m04-app .lab/build.log
