#!/usr/bin/env bash
# Exercise 5.1: starts the lab registry and pushes Monday's release as 1.0.0 (run from the repository root).
set -u
REG=127.0.0.1:5001
if ! docker image inspect brightlane/pricing:0.6 > /dev/null 2>&1; then
  echo "brightlane/pricing:0.6 is missing: run lesson 4.4's session first (module-04/04-secrets-at-build-time.sh)."
  exit 1
fi
docker rm -f -v m05l02-registry m05l03-registry m05x1-registry m05x2-registry > /dev/null 2>&1
docker rm -f m05x1-api > /dev/null 2>&1
docker run -d --name m05x1-registry -p 127.0.0.1:5001:5000 registry:3.1.2 > /dev/null
sleep 2
docker tag brightlane/pricing:0.6 $REG/brightlane/pricing:1.0.0
docker push -q $REG/brightlane/pricing:1.0.0
docker image rm $REG/brightlane/pricing:1.0.0 > /dev/null
echo "Monday's release is in the registry as $REG/brightlane/pricing:1.0.0."
