#!/usr/bin/env bash
# Lesson 10.3, builds behind a TLS-intercepting proxy: the practical as a shell session.
# Run it whole from the repository root:  bash module-10/03-builds-behind-a-tls-intercepting-proxy.sh
# or copy the commands one step at a time. "Break it" steps fail on purpose.
# The lab stands in for a company network: a package index at https://host.docker.internal:8443 whose
# certificate a private test CA signed, which is what every HTTPS site looks like to a build behind a
# proxy that re-signs traffic. Port 8443 must be free.
set -u
step() { printf '\n=== %s\n' "$*"; }
B=.lab/m10l03
D=module-10/03-ca-trust
INDEX=https://host.docker.internal:8443/simple/
PY=python:3.14.9-slim-trixie
rm -rf $B && mkdir -p $B/index/simple/brightlane-tariffs
trap 'kill $index_pid 2> /dev/null' EXIT

step "0. A test CA, a package, and an index whose certificate the CA signed"
bash tools/test_ca.sh $B
docker run --rm -v "$PWD/$B:/ca:ro" --entrypoint openssl $PY x509 -in /ca/server.pem -noout -subject -issuer
python3 tools/make_wheel.py $D/brightlane_tariffs brightlane-tariffs 2026.10.0 $B/index/simple/brightlane-tariffs
python3 tools/https_index.py $B/index $B/server.pem $B/server.key > $B/index.log 2>&1 &
index_pid=$!
sleep 1
curl -s --cacert $B/test-ca.pem https://127.0.0.1:8443/simple/brightlane-tariffs/ | grep -o 'href="[^"]*"'

step "Break it: install from the index in a build"
docker build --no-cache --progress=plain -f $D/Dockerfile.no-ca $D > $B/no-ca.log 2>&1
echo "build exit code: $?"
grep -E "^#[0-9]+ [0-9.]+ (error|  cause|hint)" $B/no-ca.log | cut -d' ' -f3-

step "2. The same error from other tools, and who signed the certificate"
docker run --rm $PY python -c "import urllib.request; urllib.request.urlopen('$INDEX')" 2>&1 | tail -1
docker run --rm $PY pip download --no-deps --retries 0 -d /tmp --index-url $INDEX brightlane-tariffs 2>&1 | grep -E "brightlane-tariffs/: There was|No matching"
docker run --rm --entrypoint sh $PY -c 'openssl s_client -connect host.docker.internal:8443 -servername host.docker.internal < /dev/null 2> /dev/null | openssl x509 -noout -issuer'

step "3. Trust the CA for one build step"
docker build -q --no-cache -f $D/Dockerfile --secret id=company_ca,src=$B/test-ca.pem -t brightlane/tariffs-check $D > /dev/null && echo "built brightlane/tariffs-check"
docker run --rm brightlane/tariffs-check
echo "--- the same Dockerfile without --secret"
docker build --no-cache --progress=plain -f $D/Dockerfile $D 2>&1 | grep -E "^#[0-9]+ [0-9.]+ +cause: invalid" | cut -d' ' -f3-

step "4. What the runtime image kept"
for image in $PY brightlane/tariffs-check; do
  echo "$image: $(docker run --rm --entrypoint sh $image -c 'grep -c "BEGIN CERTIFICATE" /etc/ssl/certs/ca-certificates.crt') certificates in the trust store"
done
docker run --rm brightlane/tariffs-check python -c "import urllib.request; urllib.request.urlopen('$INDEX')" 2>&1 | tail -1
docker history --no-trunc --format '{{.CreatedBy}}' brightlane/tariffs-check | head -3 | cut -c1-60

step "5. Proxy settings: predefined build arguments"
proxy_build() {
  printf 'FROM python:3.14.9-slim-trixie\nRUN echo "during the build: HTTPS_PROXY=$HTTPS_PROXY"\n' |
    docker build --no-cache --progress=plain --build-arg HTTPS_PROXY=http://proxy.lab.invalid:3128 "$@" - 2>&1
}
proxy_build -t m10l03-proxy-args | grep -E "^#[0-9]+ [0-9.]+ during" | cut -d' ' -f3-
docker history --no-trunc --format '{{.CreatedBy}}' m10l03-proxy-args | head -1
docker run --rm m10l03-proxy-args sh -c 'echo "at run time: HTTPS_PROXY=${HTTPS_PROXY:-unset}"'
for mode in min max; do
  proxy_build --provenance=mode=$mode --output type=local,dest=$B/out-$mode > /dev/null
  echo "--- provenance, mode=$mode"
  python3 tools/provenance.py $B/out-$mode/provenance.json | grep -E "^build"
done

step "Clean up"
kill $index_pid && wait $index_pid 2> /dev/null; echo "index stopped"
docker image rm brightlane/tariffs-check m10l03-proxy-args > /dev/null && echo "images removed"
rm -rf $B
