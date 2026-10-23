"""Exercise 10.1: the API, the worker and the proxy of m10x1 run locked down, and the stack still works."""
import json
import secrets
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

import pytest

from common.dockerlab import REPO, docker, require_docker

HERE = Path(__file__).parent
FILES = [HERE / "compose.yaml", HERE / "compose.hardened.yaml"]
PASSWORD = REPO / ".lab" / "m10x1" / "db_password.txt"
QUOTE = {"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}
LOCKED = ("api", "worker", "proxy")
ALLOWED = {"api": set(), "worker": set(), "proxy": {"CAP_CHOWN", "CAP_SETGID", "CAP_SETUID"}}


def compose(*args, timeout=300):
    files = [arg for f in FILES for arg in ("-f", str(f))]
    return subprocess.run(["docker", "compose", *files, *args], cwd=REPO,
                          capture_output=True, text=True, timeout=timeout)


def sql(query):
    return compose("exec", "-T", "db", "psql", "-U", "pricing", "-d", "pricing", "-tAc", query).stdout.strip()


def logs_of(container):
    result = subprocess.run(["docker", "logs", "--tail", "3", container], capture_output=True, text=True)
    return result.stdout + result.stderr


@pytest.fixture(scope="module")
def stack():
    require_docker()
    if not FILES[1].exists():
        pytest.fail("module-10/exercises/exercise-1/compose.hardened.yaml is missing. Copy it from start/ and fix it.")
    if not PASSWORD.exists():
        PASSWORD.parent.mkdir(parents=True, exist_ok=True)
        PASSWORD.write_text(secrets.token_urlsafe(18) + "\n")
    up = compose("up", "-d", "--wait")
    ids = docker("ps", "-aq", "--filter", "label=com.docker.compose.project=m10x1").split()
    containers = {}
    for c in (json.loads(docker("inspect", i))[0] for i in ids):
        containers[c["Config"]["Labels"]["com.docker.compose.service"]] = c
    return up, containers


def test_the_stack_starts(stack):
    up, containers = stack
    if up.returncode != 0:
        broken = [s for s, c in containers.items() if s != "migrate" and not c["State"]["Running"]]
        logs = "".join(logs_of(containers[s]["Id"]) for s in broken)
        pytest.fail(f"up -d --wait failed; not running: {', '.join(broken) or 'none'}.\n{logs[-1500:]}")


def test_read_only_no_capabilities_no_new_privileges(stack):
    _, containers = stack
    problems = []
    for service in LOCKED:
        host = containers[service]["HostConfig"]
        if not host["ReadonlyRootfs"]:
            problems.append(f"{service}: root filesystem is writable")
        if "ALL" not in (host["CapDrop"] or []):
            problems.append(f"{service}: capabilities not dropped (cap_drop: [ALL])")
        if not any(o.startswith("no-new-privileges") for o in host["SecurityOpt"] or []):
            problems.append(f"{service}: no no-new-privileges")
    assert not problems, "; ".join(problems)


def test_only_the_capabilities_each_service_needs(stack):
    _, containers = stack
    extra = {s: sorted(set(containers[s]["HostConfig"]["CapAdd"] or []) - ALLOWED[s]) for s in LOCKED}
    extra = {s: caps for s, caps in extra.items() if caps}
    assert not extra, f"Capabilities added that the service doesn't need: {extra}"


def test_seccomp_keeps_its_default_profile(stack):
    _, containers = stack
    unconfined = [s for s in LOCKED if any("unconfined" in o for o in containers[s]["HostConfig"]["SecurityOpt"] or [])]
    assert not unconfined, f"seccomp=unconfined on: {', '.join(unconfined)}. Remove it: the default profile stays."


def test_temporary_files_work(stack):
    for service in ("api", "worker"):
        result = compose("exec", "-T", service, "python", "-c", "import tempfile; tempfile.TemporaryFile()")
        assert result.returncode == 0, f"{service} can't write a temporary file: {result.stderr.strip().splitlines()[-1]}"


def test_a_quote_and_a_statement(stack):
    request = urllib.request.Request("http://127.0.0.1:8794/quotes", data=json.dumps(QUOTE).encode(),
                                     headers={"content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            assert json.load(response)["amount_eur"] == 15.99
    except urllib.error.URLError as error:
        pytest.fail(f"The quote through the proxy failed: {error}")
    job = sql("INSERT INTO statement_jobs (site_id, period) VALUES ('site-N03', '2026-10-16') RETURNING id")
    assert job, "Couldn't queue a statement job."
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        status = sql(f"SELECT status FROM statement_jobs WHERE id = {job.splitlines()[0]}")
        if status == "done":
            return
        time.sleep(1)
    pytest.fail(f"The worker didn't finish the statement job within 30 seconds (status: {status!r}).")
