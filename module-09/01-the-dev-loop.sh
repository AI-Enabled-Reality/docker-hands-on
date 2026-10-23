#!/usr/bin/env bash
# Lesson 9.1, The dev loop: override files and Compose Watch. The practical as a shell session.
# Run it whole from the repository root:  bash module-09/01-the-dev-loop.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
# The session edits app/src/pricing/api.py and app/pyproject.toml, and puts them back when it ends.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-09/01-dev-loop
B=../../.lab/m09l01
mkdir -p $B
cp ../../app/src/pricing/api.py $B/api.py.orig; cp ../../app/pyproject.toml $B/pyproject.toml.orig
restore() { cp $B/api.py.orig ../../app/src/pricing/api.py; cp $B/pyproject.toml.orig ../../app/pyproject.toml; }
trap restore EXIT
now() { python3 -c 'import time; print(time.time())'; }
since() { python3 -c "import time; print('took %.1f s' % (time.time() - $1))"; }
# Edit /version so that it reports a marker; the dev loop has to bring it to the running API.
edit_version() { python3 - "$1" <<'PY'
import sys
from pathlib import Path
p = Path("../../app/src/pricing/api.py")
s = p.read_text()
s = s.replace('"hostname": socket.gethostname(),', f'"hostname": socket.gethostname(), "edit": "{sys.argv[1]}",', 1)
p.write_text(s)
PY
}
wait_for() {  # $1 URL, $2 text to wait for
  for i in $(seq 1 400); do curl -s -m 1 "$1" | grep -q "$2" && return; sleep 0.25; done; echo "never saw $2"
}
docker compose down -v > /dev/null 2>&1

step "1. Two files, merged"
echo "--- compose.yaml alone"
docker compose -f compose.yaml config --format json | python3 ../../tools/compose_service.py api
echo "--- compose.yaml + compose.override.yaml"
docker compose config --format json | python3 ../../tools/compose_service.py api

step "2. The dev stack, with watch"
docker compose up --watch > $B/watch.log 2>&1 &
watch_pid=$!
start=$(now); wait_for http://127.0.0.1:8700/version '"version"'; since $start
docker compose ps -a --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'

step "3. Edit the code, see it in the running API"
start=$(now)
edit_version first-edit
wait_for http://127.0.0.1:8701/version first-edit; since $start
curl -s http://127.0.0.1:8701/version; echo
grep -E "Syncing|Reloading|Started server" $B/watch.log | sed -E 's/\x1b\[[0-9;]*[mK]//g; s/^ *//' | tail -3

step "4. Change the dependencies: watch rebuilds"
old=$(docker compose ps -q api)
start=$(now)
sed -i.bak 's/^description = .*/description = "Brightlane pricing service (lesson 9.1: a dependency-file change)."/' ../../app/pyproject.toml && rm ../../app/pyproject.toml.bak
for i in $(seq 1 600); do new=$(docker compose ps -q api); [ -n "$new" ] && [ "$new" != "$old" ] && break; sleep 0.25; done
wait_for http://127.0.0.1:8701/version '"version"'; since $start
grep -E "Rebuilding|Built|Recreate" $B/watch.log | sed -E 's/\x1b\[[0-9;]*[mK]//g; s/^ *//' | awk '!seen[$0]++' | tail -3

step "5. The same code edit, the production way: rebuild and replace"
kill $watch_pid; wait $watch_pid 2> /dev/null
restore
docker compose -f compose.yaml up -d --wait > /dev/null 2>&1
start=$(now)
edit_version second-edit
docker compose -f compose.yaml up -d --build --wait api > /dev/null 2>&1
wait_for http://127.0.0.1:8700/version second-edit; since $start

step "6. Break it: bind-mount the project over /app"
restore
docker compose -f compose.yaml -f compose.override.yaml -f mount-app.yaml up -d api 2>&1 | grep -i "error" | sed -E 's/^ +//' | awk '!seen[$0]++'
docker compose ps -a --format '{{.Service}}: {{.Status}}' api
docker run --rm --entrypoint ls brightlane/pricing:dev -a /app | tr '\n' ' '; echo
ls -a ../../app | tr '\n' ' '; echo

step "Clean up"
docker compose down -v > /dev/null 2>&1 && echo "stack and volumes removed"
docker image rm brightlane/pricing:dev > /dev/null
restore; trap - EXIT
rm -rf $B
