#!/usr/bin/env bash
# Remove what this course's practicals and exercises created, and nothing else:
#   containers, volumes and networks named mNNlNN-* (lessons) or mNNxN-* (exercises),
#   the Compose projects "brightlane" and "docker-hands-on-lab",
#   and the images brightlane/* and mNNlNN-* / mNNxN-*.
# Other projects' containers and images are never touched.
#
#   bash tools/reset.sh
set -u

pattern='^m[0-9][0-9][lx][0-9]'

for project in brightlane docker-hands-on-lab; do
  docker compose -p "$project" down --volumes --remove-orphans 2>/dev/null
done

ids=$(docker ps -aq --filter "name=${pattern}")
[ -n "$ids" ] && docker rm -f $ids >/dev/null && echo "removed $(echo $ids | wc -w | tr -d ' ') containers"

vols=$(docker volume ls -q | grep -E "${pattern}" || true)
[ -n "$vols" ] && docker volume rm $vols >/dev/null && echo "removed $(echo $vols | wc -w | tr -d ' ') volumes"

nets=$(docker network ls --format '{{.Name}}' | grep -E "${pattern}" || true)
[ -n "$nets" ] && docker network rm $nets >/dev/null && echo "removed $(echo $nets | wc -w | tr -d ' ') networks"

imgs=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | grep -E "^brightlane/|${pattern}" || true)
[ -n "$imgs" ] && docker image rm $imgs >/dev/null && echo "removed $(echo $imgs | wc -w | tr -d ' ') images"

echo "reset done"
