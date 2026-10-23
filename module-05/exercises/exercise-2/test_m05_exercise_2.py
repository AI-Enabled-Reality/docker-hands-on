"""Exercise 5.2: a two-platform index in the lab registry, and a cache a new builder can use."""
import json
import os
import re
import shutil
import subprocess
import time
import urllib.request
from pathlib import Path

import pytest

from common.dockerlab import REPO, docker, require_docker

HERE = Path(__file__).parent
REG = "127.0.0.1:5001"
BUILDER = "m05x2-builder"


@pytest.fixture(scope="module")
def pushed():
    require_docker()
    script = HERE / "build.sh"
    if not script.exists():
        pytest.fail("module-05/exercises/exercise-2/build.sh is missing. Copy it from start/ and change it.")
    docker("rm", "-f", "-v", "m05l02-registry", "m05l03-registry", "m05x1-registry", "m05x2-registry", check=False)
    docker("run", "-d", "--name", "m05x2-registry", "-p", "127.0.0.1:5001:5000", "registry:3.1.2")
    time.sleep(2)
    result = subprocess.run(["bash", str(script)], cwd=REPO, capture_output=True, text=True, timeout=900)
    if result.returncode != 0:
        pytest.fail(f"build.sh failed:\n{result.stderr[-2000:]}")


def test_one_index_two_platforms(pushed):
    raw = json.loads(docker("buildx", "imagetools", "inspect", "--raw", f"{REG}/brightlane/pricing:1.2.0"))
    assert "manifests" in raw, "1.2.0 is a single manifest, not an index: build for more than one platform."
    platforms = {f"{m['platform']['os']}/{m['platform']['architecture']}" for m in raw["manifests"]}
    assert {"linux/arm64", "linux/amd64"} <= platforms, f"1.2.0 lists {sorted(platforms)}."


def test_the_cache_is_in_the_registry(pushed):
    with urllib.request.urlopen(f"http://{REG}/v2/brightlane/pricing/tags/list", timeout=10) as response:
        tags = json.load(response)["tags"]
    assert "buildcache" in tags, f"The registry has the tags {tags}, no buildcache: export the cache with --cache-to."


def test_after_a_code_change_a_new_builder_reuses_the_dependencies(pushed):
    """Like CI's next commit: a new, empty builder, one changed line of code, and the registry cache."""
    app = REPO / ".lab" / "m05x2-app"
    shutil.rmtree(app, ignore_errors=True)
    shutil.copytree(REPO / "app", app, ignore=shutil.ignore_patterns(".venv", "__pycache__", ".pytest_cache"))
    with (app / "src/pricing/quotes.py").open("a") as f:
        f.write(f"# Changed by the exercise 5.2 check at {time.time()}\n")
    image = os.environ.get("LAB_BUILDKIT_IMAGE", "moby/buildkit:v0.34.1")
    docker("buildx", "rm", BUILDER, check=False)
    docker("buildx", "create", "--name", BUILDER, "--driver", "docker-container",
           "--driver-opt", "network=host", "--driver-opt", f"image={image}",
           "--buildkitd-config", str(REPO / "module-05/03-platforms/buildkitd.toml"), "--bootstrap", timeout=300)
    try:
        result = subprocess.run(
            ["docker", "buildx", "build", "--builder", BUILDER, "--progress=plain",
             "--platform", "linux/arm64,linux/amd64", "-f", "module-04/02-multi-stage/Dockerfile",
             "--cache-from", f"type=registry,ref={REG}/brightlane/pricing:buildcache", str(app)],
            cwd=REPO, capture_output=True, text=True, timeout=900)
    finally:
        docker("buildx", "rm", BUILDER, check=False)
        shutil.rmtree(app, ignore_errors=True)
    assert result.returncode == 0, result.stderr[-2000:]
    log = result.stderr
    steps = dict(re.findall(r"^#(\d+) (\[.+)$", log, flags=re.M))

    def ran(number):
        # A step that runs prints its command's output, with timestamps: "#19 2.345 Resolved 21 packages".
        # A step taken from the cache only downloads and unpacks layers.
        return re.search(rf"^#{number} \d+\.\d+ ", log, flags=re.M) is not None

    dependencies = {n: name for n, name in steps.items() if "uv sync --locked --no-install-project" in name}
    project = {n: name for n, name in steps.items() if "uv sync --locked --no-editable" in name}
    assert len(dependencies) == 2 and len(project) == 2, \
        f"Expected each uv sync step once per platform, found: {sorted(steps.values())}"
    assert all(ran(n) for n in project), "The project's own install should run again after a code change."
    rerun = [name for n, name in dependencies.items() if ran(n)]
    assert not rerun, ("After a code change, a new builder installed the dependencies again:\n  " + "\n  ".join(rerun)
                       + "\nThe cache in the registry needs the build stage's layers too, not only the final image's.")
