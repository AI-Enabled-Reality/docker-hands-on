"""Exercise 4.2: the build fetches the rulebook, and the token is nowhere in the image."""
import gzip
import json
import secrets
import shutil
import subprocess
import tarfile
import time
from pathlib import Path

import pytest

from common.dockerlab import REPO, build, docker, require_docker, run

HERE = Path(__file__).parent
IMAGE = "brightlane/pricing:m04x2"
WORK = REPO / ".lab" / "m04x2"


@pytest.fixture(scope="module")
def token():
    require_docker()
    dockerfile = HERE / "Dockerfile"
    if not dockerfile.exists():
        pytest.fail("module-04/exercises/exercise-2/Dockerfile is missing. Copy it from start/ and fix it.")
    build(REPO / "module-04/02-multi-stage/Dockerfile", "brightlane/pricing:0.5")
    shutil.rmtree(WORK, ignore_errors=True)
    WORK.mkdir(parents=True)
    value = f"bl-rb-check-{secrets.token_hex(8)}"
    (WORK / "rulebook-token.txt").write_text(value + "\n")
    server = subprocess.Popen(["python3", "tools/rulebook_server.py", "--token-file", str(WORK / "rulebook-token.txt")],
                              cwd=REPO, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    try:
        result = subprocess.run(["docker", "build", "-f", str(dockerfile),
                                 "--build-context", "scripts=module-04/04-build-secrets",
                                 "--secret", f"id=rulebook_token,src={WORK / 'rulebook-token.txt'}",
                                 "-t", IMAGE, str(WORK)], capture_output=True, text=True, cwd=REPO)
    finally:
        server.terminate()
    if result.returncode != 0:
        pytest.fail(f"The build failed:\n{result.stderr[-2000:]}")
    yield value
    shutil.rmtree(WORK, ignore_errors=True)


def test_the_rulebook_is_in_the_image(token):
    code, out = run("--entrypoint", "python", IMAGE, "-c",
                    "import json; print(json.load(open('/app/rulebook.json'))['version'])")
    assert code == 0 and out.strip() == "2026-10", out


def test_not_in_history_or_configuration(token):
    history = docker("image", "history", "--no-trunc", "--format", "{{.CreatedBy}}", IMAGE)
    config = docker("image", "inspect", IMAGE)
    assert token not in history, "The token is in the image's history: don't pass it as a build argument."
    assert token not in config, "The token is in the image's configuration (ENV or a label?)."


def test_not_in_any_layer(token, tmp_path):
    archive = tmp_path / "image.tar"
    docker("save", IMAGE, "-o", str(archive), timeout=300)
    with tarfile.open(archive) as outer:
        for member in outer.getmembers():
            if not member.isfile():
                continue
            data = outer.extractfile(member).read()
            if data[:2] == b"\x1f\x8b":
                data = gzip.decompress(data)
            assert token.encode() not in data, f"The token is in {member.name}: a layer still holds it."
