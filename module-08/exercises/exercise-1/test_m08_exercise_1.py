"""Exercise 8.1: the stack from compose.yaml is healthy, serves a quote, publishes only the proxy, keeps data."""
import json
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

import pytest

from common.dockerlab import REPO, docker, require_docker

HERE = Path(__file__).parent
FILE = HERE / "compose.yaml"
QUOTE = {"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}


def compose(*args, timeout=300):
    return subprocess.run(["docker", "compose", "-f", str(FILE), *args], cwd=REPO,
                          capture_output=True, text=True, timeout=timeout)


def containers():
    ids = docker("ps", "-q", "--filter", "label=com.docker.compose.project=m08x1").split()
    return [json.loads(docker("inspect", i))[0] for i in ids]


def quote():
    request = urllib.request.Request("http://127.0.0.1:8781/quotes", data=json.dumps(QUOTE).encode(),
                                     headers={"content-type": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response), response.headers.get("Server", "")


@pytest.fixture(scope="module")
def stack():
    require_docker()
    if not FILE.exists():
        pytest.fail("module-08/exercises/exercise-1/compose.yaml is missing.")
    result = compose("up", "-d", "--wait")
    if result.returncode != 0:
        pytest.fail(f"docker compose up -d --wait failed:\n{result.stderr[-1500:]}")
    return containers()


def test_the_project_is_m08x1_and_healthy(stack):
    assert stack, "No running containers carry the label com.docker.compose.project=m08x1: set name: m08x1."
    checked = [c for c in stack if c["State"].get("Health")]
    assert len(checked) >= 2, "Give the database and the API a healthcheck."
    unhealthy = [c["Name"] for c in checked if c["State"]["Health"]["Status"] != "healthy"]
    assert not unhealthy, f"Not healthy: {unhealthy}"


def test_a_quote_through_the_proxy(stack):
    try:
        body, server = quote()
    except urllib.error.URLError as error:
        pytest.fail(f"No answer on 127.0.0.1:8781: {error}")
    assert server.startswith("nginx"), f"The answer came from {server!r}, not from the proxy."
    assert body["amount_eur"] == 15.99, body


def test_only_the_proxy_is_published(stack):
    published = {}
    for c in stack:
        for port, bindings in (c["NetworkSettings"]["Ports"] or {}).items():
            for b in bindings or []:
                published.setdefault(c["Name"], []).append(f'{b["HostIp"]}:{b["HostPort"]}->{port}')
    assert len(published) == 1, f"Published ports: {published}. Only the proxy should publish one."
    ((name, ports),) = published.items()
    assert ports == ["127.0.0.1:8781->8080/tcp"], f"{name} publishes {ports}; expected 127.0.0.1:8781 only."


def test_the_data_survives_down_and_up(stack):
    db = next((c["Name"].lstrip("/") for c in stack if c["Config"]["Image"].startswith("postgres")), None)
    assert db, "No postgres container in the project."
    docker("exec", db, "psql", "-U", "pricing", "-d", "pricing", "-qc",
           "INSERT INTO quotes (site_id, energy_kwh, idle_minutes, tariff_id, amount_eur) "
           "VALUES ('site-N03', 1, 0, 'tar-site-N03-2', 0.49)")
    before = docker("exec", db, "psql", "-U", "pricing", "-d", "pricing", "-tAc", "SELECT count(*) FROM quotes")
    assert compose("down").returncode == 0
    result = compose("up", "-d", "--wait")
    assert result.returncode == 0, result.stderr[-1500:]
    db = next(c["Name"].lstrip("/") for c in containers() if c["Config"]["Image"].startswith("postgres"))
    after = docker("exec", db, "psql", "-U", "pricing", "-d", "pricing", "-tAc", "SELECT count(*) FROM quotes")
    assert after == before, "The database lost its data across down and up: use a named volume."
