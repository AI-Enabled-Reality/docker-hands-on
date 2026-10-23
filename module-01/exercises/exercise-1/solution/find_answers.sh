#!/usr/bin/env bash
# One way to find every answer for exercise 1.1 (run from the repository root after setup.sh).
# It prints the facts, then writes them to the exercise's answers.toml.
set -eu
vm_pid=$(docker inspect --format '{{.State.Pid}}' m01x1-db)
container_pid=$(docker run --rm --pid=container:m01x1-db alpine:3.24.3 ps -o pid,args | awk '$2 == "postgres" {print $1; exit}')
hostname=$(docker exec m01x1-db hostname)
memory_max=$(docker exec m01x1-db cat /sys/fs/cgroup/memory.max)
cpu_max=$(docker exec m01x1-db cat /sys/fs/cgroup/cpu.max)
same=$(docker run --rm --privileged --pid=host alpine:3.24.3 sh -c "[ \$(readlink /proc/1/ns/user) = \$(readlink /proc/$vm_pid/ns/user) ] && echo true || echo false")

cat > module-01/exercises/exercise-1/answers.toml <<TOML
vm_pid = $vm_pid
container_pid = $container_pid
hostname = "$hostname"
memory_max = $memory_max
cpu_max = "$cpu_max"
shares_user_namespace = $same
TOML
cat module-01/exercises/exercise-1/answers.toml
