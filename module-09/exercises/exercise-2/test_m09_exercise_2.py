"""Exercise 9.2: no container of m09x2 has a password in its environment, and the stack works."""
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


@pytest.fixture(scope="module")
def containers():
    require_docker()
    if not FILE.exists():
        pytest.fail("module-09/exercises/exercise-2/compose.yaml is missing. Copy it from start/ and change it.")
    result = compose("up", "-d", "--wait")
    if result.returncode != 0:
        pytest.fail("docker compose up -d --wait failed. If you changed the password, the database volume still has "
                    f"the old one: down -v first.\n{result.stderr[-1200:]}")
    ids = docker("ps", "-aq", "--filter", "label=com.docker.compose.project=m09x2").split()
    return [json.loads(docker("inspect", i))[0] for i in ids]


def test_no_password_in_any_environment(containers):
    found = []
    for c in containers:
        for item in c["Config"]["Env"]:
            name = item.split("=", 1)[0]
            if "PASSWORD" in name and not name.endswith("_FILE"):
                found.append(f'{c["Name"].lstrip("/")}: {name}')
    assert not found, "Passwords in the environment: " + ", ".join(found)


def test_the_database_and_the_api_get_a_secret_file(containers):
    for service in ("db", "api"):
        c = next((c for c in containers if c["Config"]["Labels"].get("com.docker.compose.service") == service), None)
        assert c, f"No {service} container in the project."
        secrets = [m["Destination"] for m in c["Mounts"] if m["Destination"].startswith("/run/secrets/")]
        assert secrets, f"{service} has no file under /run/secrets/."


def test_config_shows_no_password(containers):
    assert "pricing-lab-only" not in compose("config").stdout, "docker compose config still contains the old password."


def test_a_quote_through_the_proxy(containers):
    request = urllib.request.Request("http://127.0.0.1:8793/quotes", data=json.dumps(QUOTE).encode(),
                                     headers={"content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            assert json.load(response)["amount_eur"] == 15.99
    except urllib.error.URLError as error:
        pytest.fail(f"The quote failed: {error}")
