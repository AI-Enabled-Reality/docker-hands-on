#!/usr/bin/env bash
# One way to investigate exercise 3.2's containers (run from the repository root after setup.sh).
for c in m03x2-a m03x2-b m03x2-c; do
  docker inspect --format "{{.Name}} state={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} error={{.State.Error}}" "$c"
done
docker logs m03x2-c 2>&1 | tail -1
