#!/usr/bin/env bash
# Lesson 8.3, Configuration: env files, interpolation, profiles and include. The practical as a shell session.
# Run it whole from the repository root:  bash module-08/03-configuration-env-files-interpolation-profiles-and-include.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-08/03-config
# Compose prints warnings with a timestamp and a level; keep the message.
plain() { sed -E 's/^time="[^"]+" level=//'; }
quote() {
  curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
    -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
}
docker compose --profile tools down -v > /dev/null 2>&1
rm -f .env

step "1. No .env yet"
docker compose config -q 2>&1 | plain | head -1

step "2. .env, and the variables the file uses"
cp .env.example .env
docker compose config --variables

step "3. What interpolation produced"
docker compose config | grep -E "image: brightlane|published|_PASSWORD:|env_file" -A0 | sed -E 's/^ +//' | sort | uniq -c

step "4. The shell beats .env, .env beats the default"
docker compose config | grep published
PROXY_PORT=8710 docker compose config | grep published

step "5. Profiles and include: which services exist"
docker compose config --services | tr '\n' ' '; echo
docker compose --profile tools config --services | tr '\n' ' '; echo

step "6. Up, and what each container got"
docker compose up -d --wait > /dev/null 2>&1
docker compose ps -a --format 'table {{.Service}}\t{{.Status}}'
quote
docker compose exec api printenv PRICING_ENVIRONMENT PRICING_LOG_FORMAT
docker compose run --rm --no-deps -e PRICING_LOG_FORMAT=text --entrypoint printenv api PRICING_LOG_FORMAT 2>/dev/null
docker compose logs --no-log-prefix api | grep -m1 '"message"' | cut -c1-110

step "7. A tool from a profile"
docker compose run --rm psql -tAc "SELECT count(*) || ' tariffs' FROM tariffs" 2>/dev/null

step "8. Break it: the new password, pasted into a file"
cat pasted-password.yaml | grep -v '^#'
docker compose -f compose.yaml -f pasted-password.yaml config 2>&1 | plain | grep -E "variable is not set|PRICING_DATABASE_PASSWORD" | sed -E 's/^ +//' | sort | uniq -c
docker compose -f compose.yaml -f pasted-password.yaml up -d --wait 2>&1 | plain | grep -iE "unhealthy|error" | head -2
docker compose logs --no-log-prefix api 2>&1 | grep -m1 "password authentication failed" | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["message"].split("failed: ")[-1])'

step "9. Back to the file that takes the password from .env"
docker compose up -d --wait > /dev/null 2>&1
docker compose ps --format 'table {{.Service}}\t{{.Status}}' | grep -E "SERVICE|api"
quote

step "Clean up"
docker compose --profile tools down -v > /dev/null 2>&1 && echo "stack and volumes removed"
rm .env
