"""Capstone: the motorway release is in the registry, runs as a production stack, and survives a restart."""
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
FILES = [HERE / "compose.yaml", HERE / "compose.prod.yaml"]
PASSWORD = REPO / ".lab" / "m11x1" / "db_password.txt"
RELEASE = "127.0.0.1:5001/brightlane/pricing:1.4.0"


def compose(*args, timeout=300):
    files = [arg for f in FILES for arg in ("-f", str(f))]
    return subprocess.run(["docker", "compose", *files, *args], cwd=REPO,
                          capture_output=True, text=True, timeout=timeout)


def sql(query):
    return compose("exec", "-T", "db", "psql", "-U", "pricing", "-d", "pricing", "-tAc", query).stdout.strip()


def container(service):
    ids = docker("ps", "-aq", "--filter", "label=com.docker.compose.project=m11x1",
                 "--filter", f"label=com.docker.compose.service={service}").split()
    assert ids, f"No {service} container in the project m11x1."
    return json.loads(docker("inspect", ids[0]))[0]


def imagetools(*args):
    result = subprocess.run(["docker", "buildx", "imagetools", "inspect", RELEASE, *args],
                            capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        pytest.fail(f"Couldn't read {RELEASE} from the lab registry. Is it up (docker compose --profile registry "
                    f"up -d --wait), and did you push the release?\n{result.stderr.strip()[-400:]}")
    return json.loads(result.stdout or "null")


def quote(site, on):
    body = json.dumps({"site_id": site, "energy_kwh": 31.4, "idle_minutes": 6, "on": on}).encode()
    request = urllib.request.Request("http://127.0.0.1:8795/quotes", data=body, headers={"content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        pytest.fail(f"A quote for {site} on {on} failed: HTTP {error.code} {error.read().decode()[:200]}")
    except urllib.error.URLError as error:
        pytest.fail(f"A quote through the proxy failed: {error}")


@pytest.fixture(scope="module")
def stack():
    require_docker()
    if not FILES[1].exists():
        pytest.fail("module-11/exercises/capstone/compose.prod.yaml is missing. Copy it from start/ and fill it in.")
    if not PASSWORD.exists():
        PASSWORD.parent.mkdir(parents=True, exist_ok=True)
        PASSWORD.write_text(secrets.token_urlsafe(18) + "\n")
    up = compose("up", "-d", "--wait")
    if up.returncode != 0:
        pytest.fail(f"docker compose up -d --wait failed:\n{up.stderr.strip()[-1500:]}")


def test_the_release_is_in_the_registry_for_both_platforms():
    platforms = {f"{m['platform']['os']}/{m['platform']['architecture']}"
                 for m in imagetools("--raw").get("manifests", []) if m.get("platform")}
    missing = {"linux/amd64", "linux/arm64"} - platforms
    assert not missing, f"{RELEASE} has no image for {', '.join(sorted(missing))}: build with --platform linux/amd64,linux/arm64."
    sbom, provenance = imagetools("--format", "{{json .SBOM}}"), imagetools("--format", "{{json .Provenance}}")
    assert sbom and set(sbom) >= {"linux/amd64", "linux/arm64"}, "The release has no SBOM for both platforms: build with --sbom=true."
    assert provenance and set(provenance) >= {"linux/amd64", "linux/arm64"}, "The release has no provenance: build with --provenance."


def test_the_stack_runs_the_release(stack):
    for service in ("api", "worker"):
        image = container(service)["Config"]["Image"]
        assert image == RELEASE, f"{service} runs {image}, not {RELEASE}."


def test_the_motorway_sites(stack):
    assert sql("SELECT count(*) FROM sites WHERE region = 'M'") == "60", "The 60 motorway sites aren't in the database."
    assert sql("SELECT count(*) FROM tariffs JOIN sites USING (site_id) WHERE region = 'M' AND price_per_kwh = 0.50 "
               "AND valid_from = DATE '2026-11-02'") == "60", "The motorway sites need their 0.50 EUR/kWh tariffs."
    assert quote("site-M01", "2026-11-02")["price_per_kwh"] == 0.5
    assert quote("site-N03", "2026-10-23")["amount_eur"] == 15.99


def test_ready_for_production(stack):
    result = subprocess.run(["python3", str(REPO / "tools" / "readiness.py"), "m11x1"],
                            capture_output=True, text=True, timeout=120)
    assert result.returncode == 0, "tools/readiness.py m11x1 found problems:\n" + result.stdout


def test_a_restart_during_a_statement(stack):
    sites = sql("SELECT count(*) FROM sites")
    jobs = [sql("INSERT INTO statement_jobs (site_id, period) VALUES ('ALL', '2026-10') RETURNING id").splitlines()[0]
            for _ in range(3)]
    deadline = time.monotonic() + 15
    while sql(f"SELECT count(*) FROM statement_jobs WHERE id IN ({','.join(jobs)}) AND status = 'running'") != "1":
        if time.monotonic() > deadline:
            pytest.fail("The worker didn't start the statement jobs within 15 seconds.")
        time.sleep(0.2)
    stop = compose("stop", timeout=240)
    assert stop.returncode == 0, stop.stderr[-500:]
    exit_code = container("worker")["State"]["ExitCode"]
    assert exit_code == 0, (f"The worker exited with code {exit_code} when the stack stopped: it was killed before it "
                            "finished its job. Give it a stop_grace_period long enough for a month's statement.")
    up = compose("up", "-d", "--wait")
    assert up.returncode == 0, up.stderr[-800:]
    deadline = time.monotonic() + 60
    while (statuses := sql(f"SELECT string_agg(status, ',' ORDER BY id) FROM statement_jobs WHERE id IN ({','.join(jobs)})")) != "done,done,done":
        if time.monotonic() > deadline:
            pytest.fail(f"After the restart, the three statement jobs are {statuses}, not all done: a job left "
                        "'running' by a killed worker is never picked up again.")
        time.sleep(0.5)
    done = sql(f"SELECT file FROM statement_jobs WHERE id = {jobs[0]}")
    assert compose("exec", "-T", "worker", "test", "-f", done).returncode == 0, f"{done} isn't in the exports volume."
    assert sql("SELECT count(*) FROM sites") == sites, "The database lost data in the restart."
