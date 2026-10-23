#!/bin/sh
# Lesson 3.2: a typical entrypoint script. It prepares something, then starts the worker.
# The last line runs the worker as a child of this shell, so the shell stays PID 1.
echo "start-worker.sh: exports go to ${PRICING_EXPORT_DIR:-/exports}"
mkdir -p "${PRICING_EXPORT_DIR:-/exports}"
pricing worker "$@"
