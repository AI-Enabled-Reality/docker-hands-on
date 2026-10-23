#!/usr/bin/env bash
# Lesson 5.3, One image for arm64 and amd64: the practical as a shell session.
# Run it whole from the repository root:  bash module-05/03-one-image-for-arm64-and-amd64.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
# Behind a TLS-intercepting proxy, the lab's own builder may need a BuildKit image that trusts your
# company's certificate authority: set LAB_BUILDKIT_IMAGE to it (lesson 10.3 shows how).
set -u
step() { printf '\n=== %s\n' "$*"; }
TIMEFORMAT='took %R s'
REG=127.0.0.1:5001

step "1. Break it: an image built on a Mac, pulled by an amd64 server"
docker build -q -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.5 app > /dev/null
docker run -d --name m05l03-registry -p 127.0.0.1:5001:5000 registry:3.1.2 > /dev/null; sleep 2
docker tag brightlane/pricing:0.5 $REG/brightlane/pricing:1.0.0
docker push -q $REG/brightlane/pricing:1.0.0
docker pull --platform linux/amd64 $REG/brightlane/pricing:1.0.0

step "2. The builders you have"
docker buildx ls

step "3. What each platform's build is told"
docker build --platform linux/arm64,linux/amd64 -f module-05/03-platforms/Dockerfile.platforms --progress=plain --no-cache module-05/03-platforms 2>&1 | grep "built on" | grep -v "RUN echo" | sed -E 's/^#[0-9]+ [0-9.]+ //'

step "4. One build, two platforms"
time docker build -q --no-cache --platform linux/arm64,linux/amd64 -f module-04/02-multi-stage/Dockerfile -t brightlane/pricing:0.7 app
docker image ls --tree brightlane/pricing:0.7
for platform in linux/arm64 linux/amd64; do
  echo "$platform: $(docker run --rm --platform $platform --entrypoint python brightlane/pricing:0.7 -c 'import platform; print(platform.machine())')"
done

step "5. Native and emulated: the same work, timed"
for platform in linux/arm64 linux/amd64; do
  docker run --rm --platform $platform --entrypoint python brightlane/pricing:0.7 -c "import time; t = time.perf_counter(); sum(i * i for i in range(5_000_000)); print('$platform', round(time.perf_counter() - t, 2), 's')"
done

step "6. Push both platforms, and the build cache, to a registry"
docker buildx build --platform linux/arm64,linux/amd64 -f module-04/02-multi-stage/Dockerfile --cache-to type=registry,ref=$REG/brightlane/pricing:buildcache,mode=max -t $REG/brightlane/pricing:1.1.0 --push app 2>&1 | grep -E "writing cache|pushing manifest" | sed -E 's/^#[0-9]+ //; s/ [0-9.]+s done$//' | cut -c1-90 | awk '!seen[$0]++'
docker buildx imagetools inspect $REG/brightlane/pricing:1.1.0 | grep -E "^Name|^Digest|Platform"

step "7. A new, empty builder: CI's first build of the day"
docker buildx create --name m05l03-builder --driver docker-container --driver-opt network=host --driver-opt image=${LAB_BUILDKIT_IMAGE:-moby/buildkit:v0.34.1} --buildkitd-config module-05/03-platforms/buildkitd.toml --bootstrap > /dev/null 2>&1
docker buildx ls | grep -A1 "^m05l03-builder"
time docker buildx build --builder m05l03-builder --platform linux/arm64,linux/amd64 -f module-04/02-multi-stage/Dockerfile -t $REG/brightlane/pricing:1.1.0 --push app > .lab/build.log 2>&1
echo "$(grep -cE "^#[0-9]+ CACHED" .lab/build.log) steps CACHED"

step "8. The same, with the cache from the registry"
docker buildx prune --builder m05l03-builder --all --force > /dev/null
time docker buildx build --builder m05l03-builder --platform linux/arm64,linux/amd64 -f module-04/02-multi-stage/Dockerfile --cache-from type=registry,ref=$REG/brightlane/pricing:buildcache -t $REG/brightlane/pricing:1.1.0 --push app > .lab/build.log 2>&1
echo "$(grep -cE "^#[0-9]+ CACHED" .lab/build.log) steps CACHED"
grep -E "importing cache manifest" .lab/build.log | sed -E 's/^#[0-9]+ //'

step "Clean up"
docker buildx rm m05l03-builder
docker rm -f -v m05l03-registry
docker image rm brightlane/pricing:0.7 $REG/brightlane/pricing:1.0.0 $REG/brightlane/pricing:1.1.0 2>/dev/null | tail -1
rm -f .lab/build.log
