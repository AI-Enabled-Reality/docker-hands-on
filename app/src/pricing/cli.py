"""The `pricing` command: one entry point for everything the image runs.

    pricing api [--host H] [--port P] [--reload]
    pricing worker [--once] [--poll S] [--pace S] [--no-graceful]
    pricing version
"""
import argparse
import json
import platform
import sys
from importlib.metadata import version

from pricing.settings import get_settings


def main(argv: list[str] | None = None) -> int:
    settings = get_settings()
    parser = argparse.ArgumentParser(prog="pricing", description="Brightlane's pricing service.")
    commands = parser.add_subparsers(dest="command", required=True)

    api = commands.add_parser("api", help="serve the pricing API")
    api.add_argument("--host", default=settings.host, help=f"address to listen on (default {settings.host})")
    api.add_argument("--port", type=int, default=settings.port, help=f"port (default {settings.port})")
    api.add_argument("--reload", action="store_true", help="restart when the code changes (development only)")

    worker = commands.add_parser("worker", help="run the statement worker")
    worker.add_argument("--once", action="store_true", help="handle at most one job, then exit")
    worker.add_argument("--poll", type=float, default=2.0, help="seconds between polls when idle (default 2)")
    worker.add_argument("--pace", type=float, default=0.0, help="seconds to pause per 1,000 rows (lab demos)")
    worker.add_argument("--no-graceful", action="store_true", help="don't handle SIGTERM (lesson 3.2)")

    commands.add_parser("version", help="print the version and exit")

    args = parser.parse_args(argv)
    if args.command == "api":
        import uvicorn

        from pricing import logs

        logs.setup()
        uvicorn.run("pricing.api:app", host=args.host, port=args.port, reload=args.reload,
                    timeout_graceful_shutdown=20, log_config=None)
        return 0
    if args.command == "worker":
        from pricing import worker as statement_worker

        return statement_worker.main(once=args.once, poll=args.poll, pace=args.pace, graceful=not args.no_graceful)
    print(json.dumps({"version": version("brightlane-pricing"), "python": platform.python_version()}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
