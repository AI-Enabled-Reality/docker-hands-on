"""Exercise 10.2: the image in the lab registry has an SBOM and provenance, and the answers match the SBOM."""
import json
import subprocess
from pathlib import Path

import pytest

from common.dockerlab import load_answers, require_docker

HERE = Path(__file__).parent
IMAGE = "127.0.0.1:5001/brightlane/pricing:m10x2"


def attestation(kind):
    result = subprocess.run(["docker", "buildx", "imagetools", "inspect", IMAGE, "--format", f"{{{{json .{kind}}}}}"],
                            capture_output=True, text=True, timeout=60)
    if result.returncode != 0:
        pytest.fail(f"Couldn't read {IMAGE} from the registry. Is the lab registry up (docker compose --profile "
                    f"registry up -d --wait), and did you push the image?\n{result.stderr.strip()[-500:]}")
    return json.loads(result.stdout or "null")


@pytest.fixture(scope="module")
def sbom():
    require_docker()
    document = attestation("SBOM")
    if not document:
        pytest.fail(f"{IMAGE} has no SBOM attestation. Build it with --sbom=true.")
    return document.get("SPDX", document)


def kind(package):
    refs = [r["referenceLocator"] for r in package.get("externalRefs", []) if r.get("referenceType") == "purl"]
    return refs[0].split("/")[0].removeprefix("pkg:") if refs else "other"


def versions(sbom, name, package_kind):
    return {p.get("versionInfo") for p in sbom["packages"] if p["name"] == name and kind(p) == package_kind}


def test_the_image_has_an_sbom_and_provenance(sbom):
    assert sbom["packages"], "The SBOM lists no packages."
    provenance = attestation("Provenance")
    assert provenance and provenance.get("SLSA"), f"{IMAGE} has no provenance attestation. Build it with --provenance."


@pytest.mark.parametrize("key, name, package_kind", [
    ("fastapi", "fastapi", "pypi"),
    ("duckdb", "duckdb", "pypi"),
    ("debian_openssl", "openssl", "deb"),
])
def test_package_versions(sbom, key, name, package_kind):
    answer = load_answers(HERE / "answers.toml")[key]
    expected = versions(sbom, name, package_kind)
    assert answer in expected, f"{key} = {answer!r} isn't what the SBOM says for {name}."


def test_the_bundled_openssl(sbom):
    answer = load_answers(HERE / "answers.toml")["bundled_openssl"]
    bundled = {v for v in versions(sbom, "openssl-libs", "rpm") if v}
    assert answer and any(v == answer or v.startswith(answer + "-") for v in bundled), (
        f"bundled_openssl = {answer!r}: look for an OpenSSL package that isn't a Debian one.")


def test_the_number_of_debian_packages(sbom):
    answer = load_answers(HERE / "answers.toml")["debian_packages"]
    expected = len({(p["name"], p.get("versionInfo")) for p in sbom["packages"] if kind(p) == "deb"})
    assert answer == expected, f"debian_packages = {answer}: count the packages of type deb."
