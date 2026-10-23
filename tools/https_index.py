"""Serve a folder over HTTPS on 127.0.0.1:8443, with a certificate from tools/test_ca.sh (lesson 10.3).

    python3 tools/https_index.py <folder> <server.pem> <server.key>

Python's own directory listings are valid "simple" package index pages: uv and pip read the links.
Builds reach it at https://host.docker.internal:8443 (Docker Desktop's name for your Mac).
"""
import functools
import http.server
import ssl
import sys

folder, cert, key = sys.argv[1:4]
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(cert, key)
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=folder)
server = http.server.ThreadingHTTPServer(("127.0.0.1", 8443), handler)
server.socket = context.wrap_socket(server.socket, server_side=True)
print("package index: https://127.0.0.1:8443/simple/", flush=True)
server.serve_forever()
