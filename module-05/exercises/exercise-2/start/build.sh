#!/usr/bin/env bash
# Exercise 5.2: build the pricing image and push it to the lab registry (run from the repository root).
# Today: one platform, yours, and no cache that a new builder could use.
set -eu
REG=127.0.0.1:5001
docker build -f module-04/02-multi-stage/Dockerfile -t $REG/brightlane/pricing:1.2.0 app
docker push $REG/brightlane/pricing:1.2.0
