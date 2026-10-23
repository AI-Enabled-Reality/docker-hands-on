"""Exercise 3.1: an idle worker must stop in under 2 seconds, with exit code 0."""
import subprocess
import time
from pathlib import Path

import pytest

from common.dockerlab import REPO, docker, inspect, require_docker

HERE = Path(__file__).parent
IMAGE = "brightlane/pricing:m03x1"
DB, WORKER = "m03x1-db", "m03x1-worker"
DB_URL = "postgresql://pricing:pricing-lab-only@localhost:5432/pricing"


@pytest.fixture(scope="module")
def stopped():
    require_docker()
    for name in ("Dockerfile", "start-worker.sh"):
        if not (HERE / name).exists():
            pytest.fail(f"module-03/exercises/exercise-1/{name} is missing. Copy it from start/ and fix it.")
    build = subprocess.run(["docker", "build", "-q", "-f", str(HERE / "Dockerfile"), "--build-context", f"scripts={HERE}",
                            "-t", IMAGE, str(REPO / "app")], capture_output=True, text=True, cwd=REPO)
    if build.returncode != 0:
        pytest.fail(f"The build failed:\n{build.stderr[-2000:]}")
    subprocess.run(["bash", "tools/pricing-db.sh", DB], cwd=REPO, check=True, capture_output=True)
    docker("rm", "-f", WORKER, check=False)
    docker("run", "-d", "--name", WORKER, "--network", f"container:{DB}", "-e", f"PRICING_DATABASE_URL={DB_URL}", IMAGE)
    deadline = time.monotonic() + 20
    while "statement worker" not in docker("logs", WORKER, check=False) and time.monotonic() < deadline:
        time.sleep(0.3)
    started = time.monotonic()
    docker("stop", WORKER)
    took = time.monotonic() - started
    state = inspect(WORKER)["State"]
    docker("rm", "-f", WORKER, check=False)
    docker("rm", "-f", "-v", DB, check=False)
    return took, state


def test_stops_in_under_2_seconds(stopped):
    took, _ = stopped
    assert took < 2, f"docker stop took {took:.1f} s: the worker never got the SIGTERM. Who is PID 1?"


def test_exit_code_0(stopped):
    _, state = stopped
    assert state["ExitCode"] == 0, f"exit code {state['ExitCode']}: the worker didn't stop on its own."
