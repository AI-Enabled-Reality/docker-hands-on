#!/usr/bin/env bash
# Lesson 5.1, Inside an image: index, manifest, config. The practical as a shell session.
# Run it whole from the repository root:  bash module-05/01-inside-an-image.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }

rm -rf .lab/m05l01 && mkdir -p .lab/m05l01

step "1. The Python image's index, from Docker Hub"
docker buildx imagetools inspect python:3.14.9-slim-trixie | head -3

step "2. The same index, as the JSON document it is"
docker buildx imagetools inspect --raw python:3.14.9-slim-trixie > .lab/m05l01/python-index.json
shasum -a 256 .lab/m05l01/python-index.json
python3 tools/oci_tree.py .lab/m05l01/python-index.json

step "3. The pricing image, saved to disk as an OCI layout"
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
docker save brightlane/pricing:0.5 -o .lab/m05l01/pricing.tar
mkdir .lab/m05l01/pricing && tar -xf .lab/m05l01/pricing.tar -C .lab/m05l01/pricing
ls .lab/m05l01/pricing
ls .lab/m05l01/pricing/blobs/sha256 | wc -l

step "4. From the index to the layers"
python3 tools/oci_tree.py .lab/m05l01/pricing

step "5. The config: what docker run reads"
python3 tools/oci_tree.py .lab/m05l01/pricing config

step "6. A digest is the hash of the bytes"
(cd .lab/m05l01/pricing/blobs/sha256 && shasum -a 256 * | awk '$1 == $2 {same++} END {print same " of " NR " files are named after the SHA-256 of their content"}')
python3 -m json.tool .lab/m05l01/pricing/index.json | grep -E '"(digest|io.containerd.image.name)"'
docker image inspect --format '{{.Id}}' brightlane/pricing:0.5

step "7. Rebuild from the cache: the same manifest, a new index"
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
docker image ls --tree brightlane/pricing:0.5
docker build -q --provenance=false -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5-plain app > /dev/null
docker image ls --tree brightlane/pricing:0.5-plain

step "8. Break it: ask for a platform the index doesn't list"
docker pull --platform linux/riscv64 python:3.14.9-slim-trixie
docker run --rm --platform linux/s390x brightlane/pricing:0.5 version

step "Clean up"
docker image rm brightlane/pricing:0.5-plain
rm -rf .lab/m05l01
