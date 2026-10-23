#!/usr/bin/env bash
# Lesson 3.1, Run, watch and inspect: the practical as a shell session.
# Run it whole from the repository root:  bash module-03/01-run-watch-and-inspect.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. Start the pricing database"
docker run -d --name m03l01-db -e POSTGRES_USER=pricing -e POSTGRES_PASSWORD=pricing-lab-only -e POSTGRES_DB=pricing postgres:18.6-trixie
sleep 3
docker ps --filter name=m03l01-db --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

step "2. Read its logs"
docker logs --tail 3 m03l01-db

step "3. Copy the schema and the seed in, and load them"
docker cp app/db/init/. m03l01-db:/tmp/init/
docker exec m03l01-db ls /tmp/init
docker exec m03l01-db psql -U pricing -d pricing -q -f /tmp/init/01-schema.sql -f /tmp/init/02-seed.sql -o /dev/null
docker exec m03l01-db psql -U pricing -d pricing -c "SELECT site_id, site_name, chargers FROM sites ORDER BY site_id LIMIT 4"
docker exec m03l01-db psql -U pricing -d pricing -tAc "SELECT count(*) FROM session_charges"

step "4. Ask Docker what it knows"
docker inspect --format 'status={{.State.Status}} pid={{.State.Pid}} started={{.State.StartedAt}}' m03l01-db
docker inspect --format '{{range $name, $net := .NetworkSettings.Networks}}{{$name}}: {{$net.IPAddress}}{{end}}' m03l01-db
docker inspect --format '{{json .Config.Env}}' m03l01-db
docker inspect --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{end}}' m03l01-db

step "5. Watch it work"
docker exec m03l01-db psql -U pricing -d pricing -qc "SELECT sum(x) FROM generate_series(1, 100000000) AS x" > /dev/null &
sleep 1
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}" m03l01-db
docker top m03l01-db -o pid,etime,args | head -4
wait
sleep 1
docker events --since 1m --until 0s --filter container=$(docker inspect --format '{{.Id}}' m03l01-db) --format '{{.Action}}' | sort | uniq -c

step "6. Break it: the wrong command for the container's state"
docker stop m03l01-db
docker exec m03l01-db psql -U pricing -d pricing -c "SELECT 1"
docker start m03l01-db
docker rm m03l01-db

step "Clean up"
docker rm -f -v m03l01-db
