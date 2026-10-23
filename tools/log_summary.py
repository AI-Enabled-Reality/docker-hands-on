"""Count JSON log lines by logger and level, and the HTTP status codes in access logs (lesson 11.1).

    docker compose logs --no-log-prefix api | python3 tools/log_summary.py

A line that isn't JSON is counted as such: in a log collector, it would arrive as plain text.
"""
import json
import re
import sys
from collections import Counter

loggers, statuses, other = Counter(), Counter(), 0
for line in sys.stdin:
    try:
        entry = json.loads(line)
    except ValueError:
        other += 1
        continue
    loggers[f"{entry['logger']} ({entry['level']})"] += 1
    if entry["logger"] == "uvicorn.access":
        match = re.search(r'"(\w+) (\S+) HTTP/[\d.]+" (\d+)', entry["message"])
        if match:
            statuses[f"{match[1]} {match[2]} {match[3]}"] += 1
for name, n in loggers.most_common():
    print(f"{n:>6}  {name}")
for request, n in statuses.most_common():
    print(f"{n:>6}    {request}")
if other:
    print(f"{other:>6}  lines that aren't JSON")
