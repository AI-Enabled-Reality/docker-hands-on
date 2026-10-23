"""Exercise 4.1: a multi-stage uv build that is small and keeps its dependency layer cached."""
import json
import shutil
import subprocess
import time
from pathlib import Path

import pytest

from common.dockerlab import REPO, build, require_docker, run

HERE = Path(__file__).parent
IMAGE = "brightlane/pricing:m04x1"
COPY = REPO / ".lab" / "m04x1-app"


@pytest.fixture(scope="module")
def second_build_log():
    require_docker()
    dockerfile = HERE / "Dockerfile"
    if not dockerfile.exists():
        pytest.fail("module-04/exercises/exercise-1/Dockerfile is missing. Copy it from start/ and rewrite it.")
    shutil.rmtree(COPY, ignore_errors=True)
    shutil.copytree(REPO / "app", COPY, ignore=shutil.ignore_patterns(".venv", "__pycache__", ".env"))
    build(dockerfile, IMAGE, context=".lab/m04x1-app")
    with (COPY / "src" / "pricing" / "quotes.py").open("a") as f:
        f.write(f"# changed by the check at {time.time()}\n")
    result = subprocess.run(["docker", "build", "--progress=plain", "-f", str(dockerfile), "-t", IMAGE, str(COPY)],
                            capture_output=True, text=True, cwd=REPO)
    shutil.rmtree(COPY, ignore_errors=True)
    if result.returncode != 0:
        pytest.fail(f"The second build failed:\n{result.stderr[-2000:]}")
    return result.stderr


def test_it_runs(second_build_log):
    code, out = run(IMAGE, "version")
    assert code == 0 and json.loads(out.strip().splitlines()[-1])["version"] == "1.0.0", out


def test_no_uv_source_or_caches(second_build_log):
    code, out = run("--entrypoint", "sh", IMAGE, "-c",
                    "command -v uv; ls -d /app/src /root/.cache/pip /root/.cache/uv 2>/dev/null; true")
    assert out.strip() == "", f"The runtime image still holds: {out.strip()}"


def test_dependencies_stay_cached_after_a_code_change(second_build_log):
    steps = {}
    for line in second_build_log.splitlines():
        parts = line.split(" ", 1)
        if len(parts) == 2 and parts[0].startswith("#") and parts[1].startswith("["):
            steps.setdefault(parts[0], parts[1])
        if len(parts) == 2 and parts[1] == "CACHED":
            steps[parts[0]] = steps.get(parts[0], "") + " => CACHED"
    deps = [s for s in steps.values() if "--no-install-project" in s]
    assert deps, "No step runs `uv sync … --no-install-project`: install the dependencies on their own first."
    assert all(s.endswith("=> CACHED") for s in deps), f"The dependency step ran again after a code change: {deps}"
