"""Small helpers for the exercise checks: run the docker CLI and read what it says.

The checks drive the same `docker` command you type in the lessons, through subprocess, so
nothing here hides how Docker works. Every helper fails with a message that says what to do.
"""
import json
import re
import shutil
import subprocess
import tomllib
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


UNITS = {"B": 1, "kB": 1e3, "KB": 1e3, "MB": 1e6, "GB": 1e9, "KiB": 2**10, "MiB": 2**20, "GiB": 2**30}


def parse_size(text):
    """'31.5MB' -> 31500000.0 (docker prints decimal units in `ps -s` and `system df`)."""
    match = re.fullmatch(r"\s*([\d.]+)\s*([A-Za-z]+)\s*", text)
    if not match or match.group(2) not in UNITS:
        raise ValueError(f"not a size: {text!r}")
    return float(match.group(1)) * UNITS[match.group(2)]
