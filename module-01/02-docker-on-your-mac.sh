#!/usr/bin/env bash
# Lesson 1.2, Docker on your Mac: the practical as a shell session.
# Run it whole from the repository root:  bash module-01/02-docker-on-your-mac.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

step "1. Two programs: a client on macOS, a server in Linux"
docker version

step "2. Where the client sends its requests"
docker context ls

step "3. What the server says about itself"
docker info --format 'OS: {{.OperatingSystem}} | kernel: {{.KernelVersion}} | arch: {{.Architecture}}'
docker info --format 'CPUs: {{.NCPU}} | memory: {{.MemTotal}} bytes | cgroup v{{.CgroupVersion}}'
docker info --format 'storage: {{.Driver}} {{json .DriverStatus}} | runtime: {{.DefaultRuntime}} | logs: {{.LoggingDriver}}'

step "4. Break it: talk to a daemon that isn't there"
docker --host unix:///tmp/no-such-docker.sock ps

step "5. Start something to look for"
docker run -d --name m01l02-sleeper alpine:3.24.3 sleep 600
docker inspect --format '{{.State.Pid}}' m01l02-sleeper

step "6. Look inside the VM (a privileged helper: lab only)"
docker run --rm --privileged --pid=host alpine:3.24.3 ps -o pid,ppid,args | grep -E "PID|initd|containerd |dockerd|shim.*$(docker inspect --format '{{.Id}}' m01l02-sleeper)|sleep 600"

step "Clean up"
docker rm -f m01l02-sleeper
