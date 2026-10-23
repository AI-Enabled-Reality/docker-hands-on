#!/usr/bin/env bash
# Exercise 5.2, a possible solution: both platforms in one index, and the whole build cache in the registry.
set -eu
REG=127.0.0.1:5001
docker buildx build --platform linux/arm64,linux/amd64 \
  -f module-04/02-multi-stage/Dockerfile \
  --cache-to type=registry,ref=$REG/brightlane/pricing:buildcache,mode=max \
  -t $REG/brightlane/pricing:1.2.0 --push app
