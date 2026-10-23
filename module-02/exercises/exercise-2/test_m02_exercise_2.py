"""Exercise 2.2: one image, every program of the pricing service."""
import json
from pathlib import Path

import pytest

from common.dockerlab import build, docker, inspect, require_docker, run, wait_http

HERE = Path(__file__).parent
IMAGE = "brightlane/pricing:m02x2"
NAME = "m02x2-check"
PORT = 8712


@pytest.fixture(scope="module")
def image():
    require_docker()
    dockerfile = HERE / "Dockerfile"
    if not dockerfile.exists():
        pytest.fail("module-02/exercises/exercise-2/Dockerfile is missing. Copy it from start/ and change it.")
    build(dockerfile, IMAGE)
    yield IMAGE


def test_no_arguments_starts_the_api(image):
    docker("rm", "-f", NAME, check=False)
    docker("run", "-d", "--name", NAME, "-p", f"127.0.0.1:{PORT}:8000", image)
    try:
        assert wait_http(f"http://127.0.0.1:{PORT}/health/live") == '{"status":"ok"}'
    finally:
        docker("rm", "-f", NAME, check=False)


def test_version(image):
    code, out = run(image, "version")
    assert code == 0, out
    assert json.loads(out.strip().splitlines()[-1])["version"] == "1.0.0"


def test_help(image):
    code, out = run(image, "--help")
    assert code == 0 and "usage: pricing" in out, out


def test_worker_once(image):
    code, out = run(image, "worker", "--once")
    # There's no database yet, so the worker starts, says so, and exits with code 1.
    assert "statement worker" in out and "database unreachable" in out, out
    assert code == 1


def test_entrypoint_in_exec_form(image):
    entrypoint = inspect(image)["Config"].get("Entrypoint") or []
    assert entrypoint, "No ENTRYPOINT: `docker run IMAGE version` would look for a program called version."
    assert entrypoint[:2] != ["/bin/sh", "-c"], "Use the JSON (exec) form, or the arguments are ignored."
