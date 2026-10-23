#!/usr/bin/env bash
# Lesson 1.3, A container is a process: the practical as a shell session.
# Run it whole from the repository root:  bash module-01/03-a-container-is-a-process.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. Start the pricing database with a memory and a CPU limit"
docker run -d --name m01l03-db -e POSTGRES_PASSWORD=pricing-lab-only --memory 256m --cpus 0.5 postgres:18.6-trixie
for i in $(seq 1 30); do docker exec m01l03-db pg_isready -q 2>/dev/null && break; sleep 1; done
docker exec m01l03-db pg_isready

step "2. The processes, seen from inside the container's PID namespace"
docker run --rm --pid=container:m01l03-db alpine:3.24.3 ps -o pid,ppid,args

step "3. The same processes, seen from the VM"
docker inspect --format '{{.State.Pid}}' m01l03-db
docker top m01l03-db -o pid,ppid,args

step "4. Namespaces: the VM's PID 1 against the database's process"
pid=$(docker inspect --format '{{.State.Pid}}' m01l03-db)
docker run --rm --privileged --pid=host alpine:3.24.3 sh -c "for ns in pid net mnt uts ipc user; do echo \$ns \$(readlink /proc/1/ns/\$ns) \$(readlink /proc/$pid/ns/\$ns); done"
docker exec m01l03-db hostname
docker exec m01l03-db hostname -I

step "5. cgroups: the limits, as the kernel stores them"
docker exec m01l03-db cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.PIDs}}" m01l03-db

step "6. Break it: kill the process from the VM"
docker run --rm --privileged --pid=host alpine:3.24.3 kill -9 "$pid"
sleep 1
docker ps -a --filter name=m01l03-db --format "{{.Names}}: {{.Status}}"

step "Clean up"
docker rm m01l03-db
