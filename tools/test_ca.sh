#!/usr/bin/env bash
# Lesson 10.3: a test certificate authority and a server certificate it signs, for the lab's HTTPS
# package index at https://host.docker.internal:8443. Lab only: these keys protect nothing real.
#   bash tools/test_ca.sh <folder>
# Writes test-ca.pem (the CA's certificate, what a build must trust), test-ca.key, server.pem and
# server.key. The certificates are made in a container, so every Mac gets the same OpenSSL, with the
# extensions Python 3.13's strict verification requires (key usage, authority key identifier).
set -eu
out="$1"
mkdir -p "$out"
docker run --rm -v "$(cd "$out" && pwd):/out" --entrypoint sh python:3.14.9-slim-trixie -c '
set -e
cd /out
openssl req -x509 -newkey rsa:2048 -nodes -days 30 -keyout test-ca.key -out test-ca.pem \
  -subj "/O=Brightlane Lab/CN=Brightlane Lab Test CA" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" 2> /dev/null
openssl req -newkey rsa:2048 -nodes -keyout server.key -out server.csr \
  -subj "/O=Brightlane Lab/CN=host.docker.internal" 2> /dev/null
printf "%s\n" "subjectAltName=DNS:host.docker.internal,DNS:localhost,IP:127.0.0.1" "extendedKeyUsage=serverAuth" \
  "keyUsage=critical,digitalSignature,keyEncipherment" "basicConstraints=CA:FALSE" \
  "authorityKeyIdentifier=keyid,issuer" > server.ext
openssl x509 -req -in server.csr -CA test-ca.pem -CAkey test-ca.key -CAcreateserial -days 30 \
  -extfile server.ext -out server.pem 2> /dev/null
rm server.csr server.ext test-ca.srl
chmod 644 *.pem *.key'
