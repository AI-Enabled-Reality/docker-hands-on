"""Logging to standard output, as text for people or as JSON for log collectors.

A container's logs are whatever its processes write to stdout and stderr; Docker collects them
(`docker logs`). So the app writes there, one line per event, and never to files.
"""
import json
import logging
import sys
from datetime import UTC, datetime

from pricing.settings import get_settings


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entry = {
            "ts": datetime.fromtimestamp(record.created, UTC).isoformat(timespec="milliseconds"),
            "level": record.levelname.lower(),
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            entry["error"] = self.formatException(record.exc_info)
        return json.dumps(entry)


def setup() -> None:
    handler = logging.StreamHandler(sys.stdout)
    if get_settings().log_format == "json":
        handler.setFormatter(JsonFormatter())
    else:
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
    root = logging.getLogger()
    root.handlers[:] = [handler]
    root.setLevel(logging.INFO)
