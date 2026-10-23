"""Exercise 3.2: checks your post-mortem against what Docker recorded."""
from pathlib import Path

from common.dockerlab import docker, inspect, load_answers, require_docker

HERE = Path(__file__).parent


def setup_module():
    require_docker()


def answers(name):
    return load_answers(HERE / "answers.toml")[name]


def test_a():
    state = inspect("m03x2-a")["State"]
    assert answers("m03x2-a")["exit_code"] == state["ExitCode"]
    assert answers("m03x2-a")["cause"] == ("out-of-memory" if state["OOMKilled"] else "app-error"), \
        "Look at .State.OOMKilled, not only the exit code: 137 means SIGKILL, from whoever sent it."


def test_b():
    state = inspect("m03x2-b")["State"]
    assert answers("m03x2-b")["exit_code"] == state["ExitCode"]
    assert answers("m03x2-b")["state"] == state["Status"], "Did the container ever start?"
    assert answers("m03x2-b")["cause"] == "program-not-found", "Read .State.Error."


def test_c():
    state = inspect("m03x2-c")["State"]
    assert answers("m03x2-c")["exit_code"] == state["ExitCode"]
    assert answers("m03x2-c")["cause"] == "app-error"
    last = docker("logs", "m03x2-c").splitlines()[-1] if docker("logs", "m03x2-c") else ""
    given = answers("m03x2-c")["last_log_line"].strip()
    assert given and given in last, f"The last log line is: {last}"
