"""When each container of a Compose project started, became healthy and exited (lesson 8.2).

    docker inspect $(docker compose ps -aq) | python3 tools/compose_timeline.py

Times are seconds after the first container started. "healthy" is the first passing healthcheck that
Docker still keeps in its log (the last five), so run it soon after `docker compose up`.
"""
import json
import sys
from datetime import datetime


def when(stamp):
    """Docker's timestamps have nanoseconds; Python's fromisoformat takes microseconds."""
    return datetime.fromisoformat(stamp[:26].rstrip("Z") + "+00:00")


containers = json.load(sys.stdin)
zero = min(when(c["State"]["StartedAt"]) for c in containers)
for c in sorted(containers, key=lambda c: c["State"]["StartedAt"]):
    state = c["State"]
    service = c["Config"]["Labels"].get("com.docker.compose.service", c["Name"])
    line = f"{service:<8} started {(when(state['StartedAt']) - zero).total_seconds():4.1f} s"
    passed = [check["End"] for check in state.get("Health", {}).get("Log", []) if check["ExitCode"] == 0]
    if passed:
        line += f", healthy {(when(min(passed)) - zero).total_seconds():4.1f} s"
    if not state["Running"]:
        line += f", exited {(when(state['FinishedAt']) - zero).total_seconds():4.1f} s"
    print(line)
