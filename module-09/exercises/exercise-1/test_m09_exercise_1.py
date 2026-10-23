"""Exercise 9.1: a code edit reaches the same container in seconds; a dependency change replaces it."""
import json
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path

import pytest

from common.dockerlab import REPO, docker, require_docker

HERE = Path(__file__).parent
API = REPO / "app/src/pricing/api.py"
PYPROJECT = REPO / "app/pyproject.toml"
BACKUP = REPO / ".lab/m09x1"


def version():
    try:
        with urllib.request.urlopen("http://127.0.0.1:8791/version", timeout=2) as response:
            return json.load(response)
    except OSError:
        return None


def api_container():
    return docker("ps", "-q", "--filter", "label=com.docker.compose.project=m09x1",
                  "--filter", "label=com.docker.compose.service=api")


def wait(condition, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if condition():
            return True
        time.sleep(0.25)
    return False


@pytest.fixture(scope="module")
def watching():
    require_docker()
    if not (HERE / "compose.override.yaml").exists():
        pytest.fail("module-09/exercises/exercise-1/compose.override.yaml is missing. Copy it from start/ and rewrite it.")
    BACKUP.mkdir(parents=True, exist_ok=True)
    shutil.copy(API, BACKUP / "api.py")
    shutil.copy(PYPROJECT, BACKUP / "pyproject.toml")
    subprocess.run(["docker", "compose", "down", "-v"], cwd=HERE, capture_output=True, timeout=120)
    log = (BACKUP / "watch.log").open("w")
    process = subprocess.Popen(["docker", "compose", "up", "--watch"], cwd=HERE, stdout=log, stderr=subprocess.STDOUT)
    try:
        started = time.monotonic()
        while version() is None:
            if time.monotonic() - started > 30 and api_container() == "":
                log.flush()
                tail = (BACKUP / "watch.log").read_text().strip().splitlines()[-3:]
                pytest.fail("The API container isn't running. The end of docker compose up --watch's output:\n"
                            + "\n".join(tail))
            if time.monotonic() - started > 240:
                pytest.fail(f"The API never answered on 127.0.0.1:8791. See {BACKUP / 'watch.log'}.")
            time.sleep(1)
        yield
    finally:
        shutil.copy(BACKUP / "api.py", API)
        shutil.copy(BACKUP / "pyproject.toml", PYPROJECT)
        process.terminate()
        process.wait(timeout=60)


def test_a_code_edit_reaches_the_same_container(watching):
    before = api_container()
    marker = f"check-{int(time.time())}"
    API.write_text(API.read_text().replace('"hostname": socket.gethostname(),',
                                           f'"hostname": socket.gethostname(), "edit": "{marker}",', 1))
    seen = wait(lambda: (version() or {}).get("edit") == marker, 5)
    assert seen, "The edit didn't reach the API within 5 seconds."
    assert api_container() == before, "The API's container was replaced: the edit should be synced, not rebuilt."


def test_a_dependency_change_replaces_the_container(watching):
    before = api_container()
    PYPROJECT.write_text(PYPROJECT.read_text().replace(
        'description = "', 'description = "(exercise 9.1 check) ', 1))
    replaced = wait(lambda: api_container() not in ("", before), 180)
    assert replaced, "Changing pyproject.toml didn't replace the API's container within 3 minutes."
    assert wait(lambda: version() is not None, 60), "The rebuilt API didn't answer."
