"""Small helpers for the exercise checks: run the docker CLI and read what it says.

The checks drive the same `docker` command you type in the lessons, through subprocess, so
nothing here hides how Docker works. Every helper fails with a message that says what to do.
"""
import json
import re
import shutil
import subprocess
import time
import tomllib
import urllib.error
import urllib.request
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent


def docker(*args, check=True, timeout=120):
    """Run `docker <args>` and return its stdout, stripped."""
    if shutil.which("docker") is None:
        pytest.fail("The docker command isn't on your PATH. Install Docker Desktop (or OrbStack/Colima).")
    result = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout)
    if check and result.returncode != 0:
        pytest.fail(f"`docker {' '.join(args)}` failed:\n{result.stderr.strip()}")
    return result.stdout.strip()


def require_docker():
    """Fail early, with an instruction, when the Docker engine doesn't answer."""
    if shutil.which("docker") is None:
        pytest.fail("The docker command isn't on your PATH. Install Docker Desktop (or OrbStack/Colima).")
    result = subprocess.run(["docker", "version", "--format", "{{.Server.Version}}"],
                            capture_output=True, text=True, timeout=30)
    if result.returncode != 0:
        pytest.fail("Docker isn't answering. Start Docker Desktop, wait for 'Engine running', then rerun.")


def inspect(name):
    """`docker inspect <name>` as a dict, or fail if it doesn't exist."""
    out = docker("inspect", name, check=False)
    if not out or out == "[]":
        pytest.fail(f"There's no container or image called {name!r}. Did you run the exercise's setup script?")
    return json.loads(out)[0]


def exists(name):
    return subprocess.run(["docker", "inspect", name], capture_output=True).returncode == 0


def load_answers(path):
    """Read an answers.toml file next to the exercise."""
    path = Path(path)
    if not path.exists():
        pytest.fail(f"{path.relative_to(REPO)} is missing. Copy it from start/ and fill it in.")
    with path.open("rb") as f:
        return tomllib.load(f)


def build(dockerfile, tag, context="app", timeout=600):
    """Build an image the way the lessons do, from the repository root."""
    result = subprocess.run(["docker", "build", "-q", "-f", str(dockerfile), "-t", tag, str(REPO / context)],
                            capture_output=True, text=True, timeout=timeout, cwd=REPO)
    if result.returncode != 0:
        pytest.fail(f"The build failed:\n{result.stderr.strip()[-2000:]}")


def run(*args, timeout=120):
    """`docker run --rm <args>`: (exit code, stdout + stderr)."""
    result = subprocess.run(["docker", "run", "--rm", *args], capture_output=True, text=True, timeout=timeout)
    return result.returncode, result.stdout + result.stderr


def wait_http(url, timeout=30):
    """GET url until it answers 200; return the body, or fail after timeout seconds."""
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=3) as response:
                return response.read().decode()
        except (urllib.error.URLError, ConnectionError, OSError) as error:
            last = error
            time.sleep(0.5)
    pytest.fail(f"{url} didn't answer within {timeout} s (last error: {last})")


UNITS = {"B": 1, "kB": 1e3, "KB": 1e3, "MB": 1e6, "GB": 1e9, "KiB": 2**10, "MiB": 2**20, "GiB": 2**30}


def parse_size(text):
    """'31.5MB' -> 31500000.0 (docker prints decimal units in `ps -s` and `system df`)."""
    match = re.fullmatch(r"\s*([\d.]+)\s*([A-Za-z]+)\s*", text)
    if not match or match.group(2) not in UNITS:
        raise ValueError(f"not a size: {text!r}")
    return float(match.group(1)) * UNITS[match.group(2)]
