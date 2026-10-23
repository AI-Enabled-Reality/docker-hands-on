"""Exercise 7.1: a non-root worker writes exports to a new volume, and they outlive its containers."""
import subprocess
from pathlib import Path

import pytest

from common.dockerlab import REPO, build, docker, require_docker, run

HERE = Path(__file__).parent
IMAGE = "brightlane/pricing:m07x1"
VOLUME = "m07x1-check"


def sql(query):
    return docker("exec", "m07x1-db", "psql", "-U", "pricing", "-d", "pricing", "-tAc", query)


def export(day):
    """Queue a statement for site-C03 on one day, run a worker once in a new container, return the job's row."""
    job = sql(f"INSERT INTO statement_jobs (site_id, period) VALUES ('site-C03', '{day}') RETURNING id").splitlines()[0]
    run("--network", "m07x1-net", "-e", "PRICING_DATABASE_PASSWORD=pricing-lab-only", "-v", f"{VOLUME}:/exports",
        IMAGE, "worker", "--once", timeout=120)
    return sql(f"SELECT status || coalesce(': ' || error, '') FROM statement_jobs WHERE id = {job}")


@pytest.fixture(scope="module")
def image():
    require_docker()
    if not (HERE / "Dockerfile").exists():
        pytest.fail("module-07/exercises/exercise-1/Dockerfile is missing. Copy it from start/ and change it.")
    build(HERE / "Dockerfile", IMAGE)
    if docker("network", "ls", "-q", "--filter", "name=^m07x1-net$") == "":
        docker("network", "create", "m07x1-net")
    if docker("ps", "-q", "--filter", "name=^m07x1-db$") == "":
        subprocess.run(["bash", "tools/pricing-db.sh", "m07x1-db", "--network", "name=m07x1-net,alias=db"],
                       cwd=REPO, check=True, capture_output=True, timeout=180)
    docker("volume", "rm", VOLUME, check=False)
    yield IMAGE
    docker("volume", "rm", VOLUME, check=False)


def test_runs_as_a_user_that_is_not_root(image):
    code, out = run("--entrypoint", "id", image, "-u")
    assert code == 0 and out.strip() != "0", "The image still runs as root (uid 0): add a user and USER."


def test_exports_to_a_new_volume(image):
    result = export("2026-10-14")
    assert result == "done", f"The export {result}. A new volume copies the owner of the image's /exports."


def test_the_exports_outlive_their_containers(image):
    export("2026-10-14")
    assert export("2026-10-15") == "done"
    code, out = run("-v", f"{VOLUME}:/exports:ro", "busybox:1.38.0", "ls", "/exports/statements/site-C03")
    assert "2026-10-14.parquet" in out and "2026-10-15.parquet" in out, \
        f"The volume should hold both days' exports, written by two containers that no longer exist: {out}"
