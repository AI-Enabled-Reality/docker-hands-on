#!/usr/bin/env bash
# Lesson 9.2, Secrets, configs and a production file: the practical as a shell session.
# Run it whole from the repository root:  bash module-09/02-secrets-configs-and-a-production-file.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
cd module-09/02-secrets
B=../../.lab/m09l02
quote() {
  curl -s -w '  (HTTP %{http_code})\n' -X POST http://127.0.0.1:8700/quotes -H 'content-type: application/json' \
    -d '{"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}'
}
docker compose down -v > /dev/null 2>&1; docker compose -f compose.env.yaml down -v > /dev/null 2>&1

step "0. A password for the database, in a file outside the repository"
mkdir -p $B
python3 -c 'import secrets; print(secrets.token_urlsafe(18))' > $B/db_password.txt
chmod 600 $B/db_password.txt
ls -l $B/db_password.txt | awk '{print $1, $5, $NF}'

step "1. Break it: the password in the environment, as in module 8"
docker compose -f compose.env.yaml up -d --wait > /dev/null 2>&1
docker inspect brightlane-api-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep PASSWORD
docker compose -f compose.env.yaml exec api sh -c 'tr "\0" "\n" < /proc/1/environ | grep PASSWORD'
docker compose -f compose.env.yaml config | grep -c "pricing-lab-only"
docker compose -f compose.env.yaml down -v > /dev/null 2>&1

step "2. The password as a secret"
docker compose up -d --wait > /dev/null 2>&1
docker inspect brightlane-api-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -i PASSWORD
docker compose config | grep -ciE "$(cat $B/db_password.txt)"
docker compose exec api ls -ln /run/secrets/
docker inspect brightlane-api-1 --format '{{range .Mounts}}{{.Type}} {{.Destination}} read-only={{not .RW}}{{println}}{{end}}' | grep secrets
quote

step "3. What a secret doesn't hide"
docker compose exec api wc -c /run/secrets/db_password

step "4. The production file: merged with -f"
docker compose -f compose.yaml -f compose.prod.yaml config --format json | python3 ../../tools/compose_service.py api
docker compose -f compose.yaml -f compose.prod.yaml up -d --wait > /dev/null 2>&1
for c in db api worker proxy; do
  docker inspect -f '{{.Name}}: restart={{.HostConfig.RestartPolicy.Name}} memory={{.HostConfig.Memory}} cpus={{.HostConfig.NanoCpus}} log={{.HostConfig.LogConfig.Type}} {{.HostConfig.LogConfig.Config}}' brightlane-$c-1
done
quote

step "5. A config: the proxy's nginx.conf"
docker compose exec proxy ls -ln /etc/nginx/nginx.conf
docker inspect brightlane-proxy-1 --format '{{range .Mounts}}{{.Type}} {{.Destination}} read-only={{not .RW}}{{println}}{{end}}' | grep nginx

step "Clean up"
docker compose -f compose.yaml -f compose.prod.yaml down -v > /dev/null 2>&1 && echo "stack and volumes removed"
rm -rf $B
