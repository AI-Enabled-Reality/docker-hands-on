"""Exercise 8.2: a backup service in profile ops: never started by up, and a restorable dump when run."""
import subprocess
from pathlib import Path

import pytest

from common.dockerlab import REPO, docker, require_docker

HERE = Path(__file__).parent
FILE = HERE / "compose.yaml"
BACKUPS = REPO / ".lab" / "m08x2"


def compose(*args, timeout=300):
    return subprocess.run(["docker", "compose", "-f", str(FILE), *args], cwd=REPO,
                          capture_output=True, text=True, timeout=timeout)


@pytest.fixture(scope="module")
def stack():
    require_docker()
    if not FILE.exists():
        pytest.fail("module-08/exercises/exercise-2/compose.yaml is missing. Copy it from start/ and add the job.")
    result = compose("up", "-d", "--wait")
    if result.returncode != 0:
        pytest.fail(f"docker compose up -d --wait failed:\n{result.stderr[-1500:]}")


def test_backup_is_in_profile_ops(stack):
    default = compose("config", "--services").stdout.split()
    with_ops = compose("--profile", "ops", "config", "--services").stdout.split()
    assert "backup" in with_ops, "There's no service called backup (with the profile ops)."
    assert "backup" not in default, "backup has no profile: docker compose up would start it."


def test_up_did_not_start_it(stack):
    created = docker("ps", "-aq", "--filter", "label=com.docker.compose.project=m08x2",
                     "--filter", "label=com.docker.compose.service=backup")
    assert created == "", "docker compose up created a backup container."


def test_a_run_writes_a_restorable_dump(stack):
    before = set(BACKUPS.glob("*.dump")) if BACKUPS.exists() else set()
    result = compose("run", "--rm", "backup")
    assert result.returncode == 0, f"The backup job failed:\n{result.stderr[-1500:]}"
    new = sorted(set(BACKUPS.glob("*.dump")) - before)
    assert new, "No new .dump file in .lab/m08x2/."
    assert new[-1].stat().st_size > 100_000, f"{new[-1].name} is too small to be the pricing database."
    listing = subprocess.run(["docker", "run", "--rm", "-i", "--entrypoint", "pg_restore", "postgres:18.6-trixie",
                              "--list"], stdin=new[-1].open("rb"), capture_output=True, timeout=60)
    assert b"TABLE DATA public session_charges" in listing.stdout, "pg_restore can't read the file's table data."
