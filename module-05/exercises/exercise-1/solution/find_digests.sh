#!/usr/bin/env bash
# Exercise 5.1, a possible solution: find both digests, then deploy by digest.
set -eu
REG=127.0.0.1:5001

# The index digest, from the registry (the same value `docker push` printed, and imagetools shows).
index=$(docker buildx imagetools inspect $REG/brightlane/pricing:1.0.0 --format '{{json .Manifest}}' \
  | python3 -c "import json, sys; print(json.load(sys.stdin)['digest'])")

# The manifest for this machine's platform, from the index's own list.
arch=$(docker version --format '{{.Server.Arch}}')
manifest=$(docker buildx imagetools inspect --raw $REG/brightlane/pricing@$index \
  | python3 -c "import json, sys; print(next(m['digest'] for m in json.load(sys.stdin)['manifests'] if m.get('platform', {}).get('architecture') == sys.argv[1]))" "$arch")

cat > module-05/exercises/exercise-1/answers.toml <<TOML
image = "$REG/brightlane/pricing@$index"
manifest = "$manifest"
TOML
cat module-05/exercises/exercise-1/answers.toml

docker rm -f m05x1-api > /dev/null 2>&1 || true
docker run -d --name m05x1-api $REG/brightlane/pricing@$index
