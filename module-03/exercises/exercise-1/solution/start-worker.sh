#!/bin/sh
# Exercise 3.1, a solution: `exec` replaces the shell with the worker, so the worker is PID 1
# and receives the SIGTERM that docker stop sends.
echo "start-worker.sh: exports go to ${PRICING_EXPORT_DIR:-/exports}"
mkdir -p "${PRICING_EXPORT_DIR:-/exports}"
exec pricing worker "$@"
