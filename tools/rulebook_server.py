"""Brightlane's tariff rulebook service, as lesson 4.4 needs it: one JSON document behind a token.

Runs on your Mac; builds reach it at http://host.docker.internal:8799/rulebook.json.

    python3 tools/rulebook_server.py --token-file .lab/m04l04/rulebook-token.txt

Stop it with Ctrl+C. Lab only: plain HTTP, one hard-coded document.
"""
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

RULEBOOK = {
    "version": "2026-10",
    "rules": [
        {"id": "rounding", "text": "Round energy and idle fees to the cent, half up."},
        {"id": "idle-fee", "text": "Charge the idle fee per started minute after the session ends."},
        {"id": "motorway", "text": "Motorway sites (site-M01 to site-M60): 0.50 EUR/kWh from 2 November 2026."},
    ],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--token-file", required=True, help="file holding the token builds must send")
    parser.add_argument("--port", type=int, default=8799)
    args = parser.parse_args()
    token = Path(args.token_file).read_text().strip()

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            ok = self.path == "/rulebook.json" and self.headers.get("Authorization") == f"Bearer {token}"
            body = json.dumps(RULEBOOK if ok else {"error": "a valid token is required"}).encode()
            self.send_response(200 if ok else 401)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, fmt, *values):
            print(f"rulebook server: {self.command} {self.path} -> {values[1]}", flush=True)

    print(f"rulebook server: listening on 127.0.0.1:{args.port}", flush=True)
    try:
        ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
    except KeyboardInterrupt:
        print("rulebook server: stopped")


if __name__ == "__main__":
    main()
