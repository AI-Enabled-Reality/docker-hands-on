"""Exercise 5.1: the deployment is pinned by digest and survives a re-pushed tag."""
import json
import re
from pathlib import Path

import pytest

from common.dockerlab import build, docker, exists, inspect, load_answers, require_docker, run

HERE = Path(__file__).parent
REG = "127.0.0.1:5001"
TAG = f"{REG}/brightlane/pricing:1.0.0"


@pytest.fixture(scope="module")
def answers():
    require_docker()
    if docker("ps", "-q", "--filter", "name=^m05x1-registry$") == "":
        pytest.fail("The registry m05x1-registry isn't running: bash module-05/exercises/exercise-1/start/setup.sh")
    return load_answers(HERE / "answers.toml")


@pytest.fixture(scope="module")
def monday():
    """Monday's release is brightlane/pricing:0.6, pushed by setup.sh: its index digest is 0.6's image ID."""
    return docker("image", "inspect", "--format", "{{.Id}}", "brightlane/pricing:0.6")


def test_the_reference_is_pinned_to_monday(answers, monday):
    image = answers["image"].strip()
    assert re.fullmatch(r"127\.0\.0\.1:5001/brightlane/pricing(:[\w.-]+)?@sha256:[0-9a-f]{64}", image), \
        "image must look like 127.0.0.1:5001/brightlane/pricing@sha256:<64 hex characters>."
    assert image.endswith("@" + monday), \
        "That digest isn't Monday's 1.0.0. Ask the registry what 1.0.0 is (imagetools inspect), right after setup.sh."
    raw = json.loads(docker("buildx", "imagetools", "inspect", "--raw", image))
    arch = docker("version", "--format", "{{.Server.Arch}}")
    platform = [m["digest"] for m in raw["manifests"] if m.get("platform", {}).get("architecture") == arch]
    assert answers["manifest"].strip() in platform, \
        f"manifest should be the digest of the linux/{arch} entry in that index, not the index itself."


def test_deployed_by_digest(answers):
    if not exists("m05x1-api"):
        pytest.fail("There's no container m05x1-api: docker run -d --name m05x1-api <the image from answers.toml>")
    container = inspect("m05x1-api")
    assert container["State"]["Running"], "m05x1-api isn't running. docker logs m05x1-api says why."
    assert container["Config"]["Image"] == answers["image"].strip(), \
        f"m05x1-api runs {container['Config']['Image']!r}: start it from the reference in answers.toml."


def test_survives_a_re_push(answers, monday):
    if not answers["image"].strip().endswith("@" + monday):
        pytest.fail("Pin the reference to Monday's digest first (the first check).")
    build("module-04/02-multi-stage/Dockerfile", "brightlane/pricing:0.5")
    try:
        docker("tag", "brightlane/pricing:0.5", TAG)
        docker("push", "-q", TAG, timeout=300)
        docker("image", "rm", TAG)
        code, pinned = run("--pull", "always", "--entrypoint", "ls", answers["image"].strip(), "-A", "/app", timeout=300)
        code_tag, tagged = run("--pull", "always", "--entrypoint", "ls", TAG, "-A", "/app", timeout=300)
    finally:
        # Put Monday's release back under 1.0.0, so the check can run again.
        docker("tag", "brightlane/pricing:0.6", TAG)
        docker("push", "-q", TAG, timeout=300)
        docker("image", "rm", TAG, check=False)
    assert code_tag == 0 and "rulebook.json" not in tagged, "After the re-push, 1.0.0 should be the image without the rulebook."
    assert code == 0 and "rulebook.json" in pinned, "Your pinned reference no longer gets Monday's image."
