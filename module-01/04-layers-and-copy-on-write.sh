#!/usr/bin/env bash
# Lesson 1.4, Layers and copy-on-write: the practical as a shell session.
# Run it whole from the repository root:  bash module-01/04-layers-and-copy-on-write.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. The layers of the Python image"
docker image history python:3.14.9-slim-trixie
docker image inspect --format '{{len .RootFS.Layers}} layers' python:3.14.9-slim-trixie

step "2. A container changes files"
docker run -d --name m01l04-scratch python:3.14.9-slim-trixie sleep 600
docker exec m01l04-scratch sh -c 'echo "tariff draft" > /tmp/note.txt'
docker exec m01l04-scratch sh -c 'echo "BRIGHTLANE_LAB=1" >> /etc/os-release'
docker exec m01l04-scratch rm -r /usr/share/doc
docker diff m01l04-scratch | grep -vE "^[ACD] /usr/share/doc/."

step "3. Another container from the same image sees none of it"
docker run --rm python:3.14.9-slim-trixie sh -c 'tail -1 /etc/os-release; ls /tmp; ls -d /usr/share/doc'

step "4. What the change costs"
docker ps -s --filter name=m01l04 --format "table {{.Names}}\t{{.Size}}"
docker image ls python:3.14.9-slim-trixie

step "5. Break it: delete 40 MB and watch the image grow"
docker exec m01l04-scratch dd if=/dev/zero of=/srv/rulebook.bin bs=1M count=40 status=none
docker commit m01l04-scratch m01l04-with-file:1
docker run --name m01l04-cleaner m01l04-with-file:1 rm /srv/rulebook.bin
docker commit m01l04-cleaner m01l04-without-file:1
docker image ls --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "IMAGE|REPOSITORY|python:3.14.9-slim-trixie|m01l04"
docker image history --format "table {{.CreatedBy}}\t{{.Size}}" m01l04-without-file:1 | head -4

step "Clean up"
docker rm -f m01l04-scratch m01l04-cleaner
docker image rm m01l04-with-file:1 m01l04-without-file:1
