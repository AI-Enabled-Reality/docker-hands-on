"""Send quote requests to the pricing API, eight at a time, and report how they went (module 11).

    python3 tools/load.py http://127.0.0.1:8700 5000
"""
import json
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

url, count = sys.argv[1].rstrip("/") + "/quotes", int(sys.argv[2])
body = json.dumps({"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}).encode()


def quote(_):
    request = urllib.request.Request(url, data=body, headers={"content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except OSError:
        return "no answer"


started = time.monotonic()
with ThreadPoolExecutor(8) as pool:
    statuses = Counter(pool.map(quote, range(count)))
took = time.monotonic() - started
print(f"{count} quotes in {took:.1f} s: " + ", ".join(f"HTTP {s} × {n}" for s, n in sorted(statuses.items(), key=str)))
