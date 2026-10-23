#!/bin/sh
# Exercise 3.1: the worker's entrypoint script. It must keep doing what it does,
# and the worker must still stop in under 2 seconds with exit code 0.
echo "start-worker.sh: exports go to ${PRICING_EXPORT_DIR:-/exports}"
mkdir -p "${PRICING_EXPORT_DIR:-/exports}"
pricing worker "$@"
