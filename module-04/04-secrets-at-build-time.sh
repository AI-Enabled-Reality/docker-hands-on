#!/usr/bin/env bash
# Lesson 4.4, Secrets at build time: the practical as a shell session.
# Run it whole from the repository root:  bash module-04/04-secrets-at-build-time.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
# Save an image to a tar file and look for the token file in every layer.
search_layers() {
  rm -rf .lab/img && mkdir -p .lab/img
  docker save "$1" -o .lab/img.tar && tar -xf .lab/img.tar -C .lab/img
  for blob in .lab/img/blobs/sha256/*; do
    if tar -tzf "$blob" 2> /dev/null | grep -qx "tmp/rulebook-token"; then
      echo "layer ${blob##*/} holds tmp/rulebook-token: $(tar -xzOf "$blob" tmp/rulebook-token)"
    fi
  done
  echo "searched $(ls .lab/img/blobs/sha256 | wc -l | tr -d ' ') blobs"
}

step "0. The token, the rulebook server, and the base image"
mkdir -p .lab/m04l04 && echo "bl-rb-4c1d9e7a52f08b36" > .lab/m04l04/rulebook-token.txt
python3 tools/rulebook_server.py --token-file .lab/m04l04/rulebook-token.txt > .lab/rulebook-server.log 2>&1 &
server=$!
sleep 1
curl -s http://127.0.0.1:8799/rulebook.json; echo
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app

step "1. Break it: the token as a build argument"
docker build --progress=plain -f module-04/04-build-secrets/Dockerfile.arg --build-context scripts=module-04/04-build-secrets --build-arg RULEBOOK_TOKEN="$(cat .lab/m04l04/rulebook-token.txt)" -t brightlane/pricing:0.6-arg .lab/m04l04 2>&1 | grep -E "rules saved|warning|SecretsUsed" | sed -E 's/^#[0-9]+ [0-9.]+ //; s/\x1b\[[0-9;]*m//g'
docker image history --no-trunc --format '{{.CreatedBy}}' brightlane/pricing:0.6-arg | grep RULEBOOK_TOKEN | cut -c1-90

step "2. Break it: copy the token in, use it, delete it"
docker build -q -f module-04/04-build-secrets/Dockerfile.copy-rm --build-context scripts=module-04/04-build-secrets -t brightlane/pricing:0.6-copy-rm .lab/m04l04
docker run --rm --entrypoint ls brightlane/pricing:0.6-copy-rm -A /tmp; echo "(/tmp is empty)"
docker image history --format '{{.CreatedBy}}' brightlane/pricing:0.6-copy-rm | head -2 | cut -c1-90
search_layers brightlane/pricing:0.6-copy-rm

step "3. The token as a build secret"
docker build --progress=plain -f module-04/04-build-secrets/Dockerfile.secret --build-context scripts=module-04/04-build-secrets --secret id=rulebook_token,src=.lab/m04l04/rulebook-token.txt -t brightlane/pricing:0.6 .lab/m04l04 2>&1 | grep -E "rules saved|warning" | sed -E 's/^#[0-9]+ [0-9.]+ //'
docker image history --no-trunc --format '{{.CreatedBy}}' brightlane/pricing:0.6 | head -1 | cut -c1-120
search_layers brightlane/pricing:0.6
docker run --rm --entrypoint python brightlane/pricing:0.6 -c "import json; print(json.load(open('/app/rulebook.json'))['rules'][2]['text'])"

step "4. What the rulebook server saw"
cat .lab/rulebook-server.log

step "Clean up"
kill $server
docker image rm brightlane/pricing:0.6-arg brightlane/pricing:0.6-copy-rm
rm -rf .lab/m04l04 .lab/img .lab/img.tar .lab/rulebook-server.log
