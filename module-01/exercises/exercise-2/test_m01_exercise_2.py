"""Exercise 1.2: checks your answers.toml against the two running containers."""
import re
from pathlib import Path

from common.dockerlab import docker, load_answers, parse_size, require_docker

HERE = Path(__file__).parent
MB = 1e6


def setup_module():
    require_docker()


def answers():
    return load_answers(HERE / "answers.toml")


def sizes(name):
    """(writable, virtual) in bytes, from `docker ps -s`: '31.5MB (virtual 192MB)'."""
    out = docker("ps", "-a", "-s", "--filter", f"name=^{name}$", "--format", "{{.Size}}")
    match = re.fullmatch(r"(\S+) \(virtual (\S+)\)", out)
    assert match, f"{name} isn't there. Run start/setup.sh again."
    return parse_size(match.group(1)), parse_size(match.group(2))


def close(answer_mb, actual_bytes):
    return abs(answer_mb * MB - actual_bytes) <= max(0.1 * actual_bytes, 0.5 * MB)


def test_export_writable_layer():
    writable, _ = sizes("m01x2-export")
    assert close(answers()["export_writable_mb"], writable), "Look at the SIZE column of docker ps -s."


def test_trim_writable_layer():
    writable, _ = sizes("m01x2-trim")
    assert close(answers()["trim_writable_mb"], writable), "Look at the SIZE column of docker ps -s."


def test_shared_image():
    writable, virtual = sizes("m01x2-export")
    assert close(answers()["shared_image_mb"], virtual - writable), \
        "The virtual size is the image plus the writable layer; the image part is shared."


def test_ensurepip_letter():
    diff = docker("diff", "m01x2-trim")
    letter = next(line.split()[0] for line in diff.splitlines() if line.endswith("/ensurepip"))
    assert answers()["ensurepip_letter"].strip().upper() == letter


def test_deleting_saved_space():
    assert answers()["deleting_saved_space"] is False, \
        "Deleting a file from a lower layer only adds a marker in the writable layer; the image stays the same size."
