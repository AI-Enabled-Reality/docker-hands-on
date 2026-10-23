#!/usr/bin/env bash
# Lesson 5.2, Tags, digests and registries: the practical as a shell session.
# Run it whole from the repository root:  bash module-05/02-tags-digests-and-registries.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
set -u
step() { printf '\n=== %s\n' "$*"; }
REG=127.0.0.1:5001

step "0. The images to push: lesson 4.2's 0.5 and lesson 4.4's 0.6 (with the rulebook)"
docker image ls brightlane/pricing | grep -E "^IMAGE|:0\.[56] "

step "1. A registry of your own"
docker run -d --name m05l02-registry -p 127.0.0.1:5001:5000 -v m05l02-registry-data:/var/lib/registry registry:3.1.2
sleep 2
curl -s http://$REG/v2/; echo

step "2. Name the image for the registry, and push it"
docker tag brightlane/pricing:0.6 $REG/brightlane/pricing:1.0.0
docker push $REG/brightlane/pricing:1.0.0

step "3. What the registry holds"
curl -s http://$REG/v2/_catalog; echo
curl -s http://$REG/v2/brightlane/pricing/tags/list; echo
curl -sI -H "Accept: application/vnd.oci.image.index.v1+json" http://$REG/v2/brightlane/pricing/manifests/1.0.0 | grep -i -E "content-type|docker-content-digest"
monday=$(curl -sI -H "Accept: application/vnd.oci.image.index.v1+json" http://$REG/v2/brightlane/pricing/manifests/1.0.0 | awk -F': ' 'tolower($1) == "docker-content-digest" {print $2}' | tr -d '\r')

step "4. Break it: push a different image under the same tag"
docker tag brightlane/pricing:0.5 $REG/brightlane/pricing:1.0.0
docker push $REG/brightlane/pricing:1.0.0 | tail -1
tuesday=$(curl -sI -H "Accept: application/vnd.oci.image.index.v1+json" http://$REG/v2/brightlane/pricing/manifests/1.0.0 | awk -F': ' 'tolower($1) == "docker-content-digest" {print $2}' | tr -d '\r')
echo "Monday:  1.0.0 = $monday"
echo "Tuesday: 1.0.0 = $tuesday"
docker image rm $REG/brightlane/pricing:1.0.0 > /dev/null
docker run --rm --entrypoint ls $REG/brightlane/pricing:1.0.0 -A /app 2>&1 | grep -v "Unable to find\|Pulling\|Digest\|Status\|Download\|complete\|exists"

step "5. Pin by digest: Monday's image is still there"
docker run --rm --entrypoint ls $REG/brightlane/pricing@$monday -A /app 2>&1 | grep -v "Unable to find\|Pulling\|Digest\|Status\|Download\|complete\|exists"

step "6. A registry name that isn't localhost"
docker tag brightlane/pricing:0.6 host.docker.internal:5001/brightlane/pricing:1.0.0
docker push host.docker.internal:5001/brightlane/pricing:1.0.0 2>&1 | grep -v -E "Waiting|Preparing"
docker image rm host.docker.internal:5001/brightlane/pricing:1.0.0 > /dev/null

step "7. What all this costs on disk"
docker system df

step "8. Which images carry the pricing service's label"
docker image ls --filter "label=org.opencontainers.image.title=Brightlane pricing service" --format "{{.ID}}  {{.Repository}}:{{.Tag}}"

step "Clean up"
docker rm -f -v m05l02-registry
docker volume rm m05l02-registry-data
docker image rm $REG/brightlane/pricing:1.0.0 $REG/brightlane/pricing@$monday 2>/dev/null | tail -1
