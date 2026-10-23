"""Exercise 6.1: the API finds its database by name on a user-defined network, and survives restarts."""
import ipaddress
import subprocess
from pathlib import Path
from urllib.parse import urlparse

import pytest

from common.dockerlab import REPO, docker, inspect, require_docker, wait_http

HERE = Path(__file__).parent
READY = "http://127.0.0.1:8761/health/ready"


@pytest.fixture(scope="module")
def started():
    require_docker()
    script = HERE / "run-api.sh"
    if not script.exists():
        pytest.fail("module-06/exercises/exercise-1/run-api.sh is missing. Copy it from start/ and change it.")
    result = subprocess.run(["bash", str(HERE / "start/setup.sh")], cwd=REPO, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        pytest.fail(f"setup.sh failed:\n{result.stderr[-1500:]}")
    result = subprocess.run(["bash", str(script)], cwd=REPO, capture_output=True, text=True, timeout=300)
    if result.returncode != 0:
        pytest.fail(f"run-api.sh failed:\n{result.stderr[-1500:]}")


def test_ready(started):
    body = wait_http(READY, timeout=30)
    assert '"ready"' in body, body


def test_published_on_loopback_only(started):
    ports = docker("port", "m06x1-api").splitlines()
    assert ports == ["8000/tcp -> 127.0.0.1:8761"], \
        f"docker port m06x1-api says {ports}: publish 8000 on 127.0.0.1:8761 only."


def test_by_name_on_a_user_defined_network(started):
    api, db = inspect("m06x1-api"), inspect("m06x1-db")
    env = dict(item.split("=", 1) for item in api["Config"]["Env"])
    host = urlparse(env.get("PRICING_DATABASE_URL", "")).hostname or ""
    try:
        ipaddress.ip_address(host)
        pytest.fail(f"PRICING_DATABASE_URL uses the IP address {host}: use a name.")
    except ValueError:
        pass
    shared = set(api["NetworkSettings"]["Networks"]) & set(db["NetworkSettings"]["Networks"])
    assert shared - {"bridge"}, "m06x1-api and m06x1-db share no user-defined network."


def test_survives_a_restart_in_the_other_order(started):
    docker("stop", "m06x1-db", "m06x1-api", timeout=60)
    docker("start", "m06x1-api")
    docker("start", "m06x1-db")
    body = wait_http(READY, timeout=30)
    assert '"ready"' in body, body
