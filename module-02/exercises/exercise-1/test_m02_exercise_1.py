"""Exercise 2.1: builds your Dockerfile, runs the image, and looks inside it."""
import shutil
from pathlib import Path

import pytest

from common.dockerlab import REPO, build, docker, require_docker, run, wait_http

HERE = Path(__file__).parent
IMAGE = "brightlane/pricing:m02x1"
NAME = "m02x1-check"
PORT = 8711


@pytest.fixture(scope="module")
def image():
    require_docker()
    dockerfile = HERE / "Dockerfile"
    if not dockerfile.exists():
        pytest.fail("module-02/exercises/exercise-1/Dockerfile is missing. Copy it from start/ and fill it in.")
    # Plant what a developer's folder holds, as long as the build runs.
    planted = []
    env, venv = REPO / "app" / ".env", REPO / "app" / ".venv"
    if not env.exists():
        env.write_text("PRICING_ADMIN_TOKEN=planted-by-the-check\n")
        planted.append(env)
    if not venv.exists():
        (venv / "bin").mkdir(parents=True)
        (venv / "bin" / "python").write_text("not a Linux binary\n")
        planted.append(venv)
    try:
        build(dockerfile, IMAGE)
    finally:
        for path in planted:
            shutil.rmtree(path) if path.is_dir() else path.unlink()
    yield IMAGE


def test_the_api_answers_on_a_published_port(image):
    docker("rm", "-f", NAME, check=False)
    docker("run", "-d", "--name", NAME, "-p", f"127.0.0.1:{PORT}:8000", image)
    try:
        assert wait_http(f"http://127.0.0.1:{PORT}/health/live") == '{"status":"ok"}'
    finally:
        docker("rm", "-f", NAME, check=False)


def test_no_env_file_in_the_image(image):
    code, out = run("--entrypoint", "sh", image, "-c", "find / -name .env -not -path '/proc/*' 2>/dev/null")
    assert out.strip() == "", f"The image contains {out.strip()}: add it to Dockerfile.dockerignore."


def test_no_local_venv_in_the_image(image):
    code, out = run("--entrypoint", "sh", image, "-c", "test -e /app/.venv && echo present || echo absent")
    assert out.strip() == "absent", "The Mac's .venv was copied into the image: ignore it."
