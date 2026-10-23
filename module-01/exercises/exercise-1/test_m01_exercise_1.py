"""Exercise 1.1: checks your answers.toml against the running container m01x1-db."""
from pathlib import Path

from common.dockerlab import docker, inspect, load_answers, require_docker

HERE = Path(__file__).parent
NAME = "m01x1-db"


def setup_module():
    require_docker()


def answers():
    return load_answers(HERE / "answers.toml")


def running():
    state = inspect(NAME)["State"]
    assert state["Running"], f"{NAME} isn't running. Start it again with start/setup.sh (the PID changes)."
    return state


def test_vm_pid():
    assert answers()["vm_pid"] == running()["Pid"], "That's not the PID the VM sees. Try docker inspect or docker top."


def test_container_pid():
    assert answers()["container_pid"] == 1, "Inside its own PID namespace, the container's main process has a special number."


def test_hostname():
    running()
    assert answers()["hostname"] == docker("exec", NAME, "hostname")


def test_memory_max():
    running()
    expected = int(docker("exec", NAME, "cat", "/sys/fs/cgroup/memory.max"))
    assert answers()["memory_max"] == expected, "Read /sys/fs/cgroup/memory.max inside the container."


def test_cpu_max():
    running()
    assert answers()["cpu_max"].strip() == docker("exec", NAME, "cat", "/sys/fs/cgroup/cpu.max")


def test_user_namespace():
    pid = running()["Pid"]
    out = docker("run", "--rm", "--privileged", "--pid=host", "alpine:3.24.3",
                 "sh", "-c", f"readlink /proc/1/ns/user; readlink /proc/{pid}/ns/user")
    vm, container = out.splitlines()
    assert answers()["shares_user_namespace"] == (vm == container)
