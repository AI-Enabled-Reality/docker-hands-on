#!/usr/bin/env bash
# Lesson 10.1, Least privilege at run time: the practical as a shell session.
# Run it whole from the repository root:  bash module-10/01-least-privilege-at-run-time.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-10/01-least-privilege
B=../../.lab/m10l01
# What a container's main process may do: user, capabilities, the no-new-privileges flag, seccomp.
privileges() {
  docker run --rm --entrypoint sh "$@" -c 'id -u; grep -E "^(Cap|NoNewPrivs|Seccomp)" /proc/1/status' \
    | awk 'NR == 1 {print "uid: " $0; next} {print}' | python3 -c '
import subprocess, sys
lines = sys.stdin.read().splitlines()
print(lines[0])
caps = [l for l in lines if l.startswith(("CapEff", "CapBnd"))]
print(subprocess.run(["python3", "../../tools/caps.py"], input="\n".join(caps), capture_output=True, text=True).stdout, end="")
print("  ".join(l.replace(":\t", ": ") for l in lines if l.startswith(("NoNewPrivs", "Seccomp"))))'
}
# Start nginx with the test configuration and the options given; report how it went.
nginx() {
  docker rm -f m10l01-proxy > /dev/null 2>&1
  docker run -d --name m10l01-proxy -p 127.0.0.1:8704:8080 \
    -v "$PWD/nginx-test.conf:/etc/nginx/nginx.conf:ro" "$@" nginx:1.30.6-alpine > /dev/null
  sleep 2
  echo "$(docker ps -a --filter name=m10l01-proxy --format '{{.Status}}') | $(curl -s -m 2 http://127.0.0.1:8704/ || echo 'no answer')"
  docker logs m10l01-proxy 2>&1 | grep -E "\[(emerg|alert)\]" | sed -E 's/^[0-9/: ]+//' | tail -2
}
docker rm -f m10l01-proxy > /dev/null 2>&1
docker compose -f compose.yaml -f compose.hardened.yaml down -v > /dev/null 2>&1
mkdir -p $B && python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > $B/db_password.txt

step "1. What a container gets by default"
echo "--- brightlane/pricing:0.5, as root"
privileges brightlane/pricing:0.5
echo "--- brightlane/pricing:0.8, as user 10001"
privileges brightlane/pricing:0.8
docker info --format '{{json .SecurityOptions}}'

step "2. Take everything away that the API doesn't use"
privileges --cap-drop ALL --security-opt no-new-privileges brightlane/pricing:0.8

step "3. Break it: a read-only root filesystem, and a temporary file"
docker run --rm --read-only --entrypoint python brightlane/pricing:0.8 -c "import tempfile; print(tempfile.mkstemp())" 2>&1 | tail -1
docker run --rm --read-only --tmpfs /tmp:size=16m --entrypoint python brightlane/pricing:0.8 -c "import tempfile; print(tempfile.mkstemp())"

step "4. Break it: the proxy, one restriction at a time"
echo "--- --read-only"; nginx --read-only
echo "--- + tmpfs for its cache and its pid file"; nginx --read-only --tmpfs /var/cache/nginx --tmpfs /run
echo "--- + --cap-drop ALL"; nginx --read-only --tmpfs /var/cache/nginx --tmpfs /run --cap-drop ALL
echo "--- + CHOWN"; nginx --read-only --tmpfs /var/cache/nginx --tmpfs /run --cap-drop ALL --cap-add CHOWN
echo "--- + SETGID, SETUID"; nginx --read-only --tmpfs /var/cache/nginx --tmpfs /run --cap-drop ALL --cap-add CHOWN --cap-add SETGID --cap-add SETUID
docker rm -f m10l01-proxy > /dev/null

step "5. The whole stack, locked down"
docker compose -f compose.yaml -f compose.hardened.yaml up -d --wait > /dev/null 2>&1
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
for s in api worker proxy; do
  docker inspect -f "$s: read-only={{.HostConfig.ReadonlyRootfs}} cap-drop={{.HostConfig.CapDrop}} cap-add={{.HostConfig.CapAdd}} {{.HostConfig.SecurityOpt}}" brightlane-$s-1
done
curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
  -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
docker compose exec db psql -U pricing -d pricing -qc "INSERT INTO statement_jobs (site_id, period) VALUES ('site-N03', '2026-10-15')"
sleep 4
docker compose exec db psql -U pricing -d pricing -tAc "SELECT 'statement job: ' || status || ', ' || rows || ' rows' FROM statement_jobs"

step "Clean up"
docker compose -f compose.yaml -f compose.hardened.yaml down -v > /dev/null 2>&1 && echo "stack and volumes removed"
rm -rf $B
