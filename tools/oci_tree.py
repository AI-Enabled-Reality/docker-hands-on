"""Print the tree of an OCI image layout, as `docker save` writes it (lesson 5.1).

    python3 tools/oci_tree.py <folder>      # the folder you unpacked the tar file into
    python3 tools/oci_tree.py <folder> config   # the image config's run settings, as docker run reads them
    python3 tools/oci_tree.py <index.json>  # an index saved with `imagetools inspect --raw`: its entries

Each line is one blob: its media type (shortened), the first 12 characters of its digest, its size,
and for manifests the platform. For a provenance attestation, it adds what the build recorded: the
images it started from and when it ran. Read the code: it only follows the JSON documents' references.
"""
import json
import sys
from pathlib import Path

SHORT = {
    "application/vnd.oci.image.index.v1+json": "index",
    "application/vnd.oci.image.manifest.v1+json": "manifest",
    "application/vnd.oci.image.config.v1+json": "config",
    "application/vnd.oci.image.layer.v1.tar+gzip": "layer (tar+gzip)",
    "application/vnd.in-toto+json": "attestation (in-toto)",
    "application/vnd.oci.empty.v1+json": "empty config",
}


def blob(root, digest):
    return root / "blobs" / digest.replace(":", "/")


def show(root, descriptor, depth=0):
    kind = SHORT.get(descriptor["mediaType"], descriptor["mediaType"])
    platform = descriptor.get("platform")
    where = "  " + "/".join(platform[k] for k in ("os", "architecture", "variant") if k in platform) if platform else ""
    if descriptor.get("annotations", {}).get("vnd.docker.reference.type") == "attestation-manifest":
        where += "  (attestations)"
    print(f"{'    ' * depth}{kind:<22} {descriptor['digest'][7:19]}  {descriptor['size']:>11,} B{where}")
    if root and kind in ("index", "manifest"):
        document = json.loads(blob(root, descriptor["digest"]).read_text())
        if kind == "index":
            for child in document["manifests"]:
                show(root, child, depth + 1)
        else:
            show(root, document["config"], depth + 1)
            for layer in document["layers"]:
                show(root, layer, depth + 1)
    if root and kind == "attestation (in-toto)":
        predicate = json.loads(blob(root, descriptor["digest"]).read_text())["predicate"]
        indent = "    " * (depth + 1)
        for source in predicate.get("buildDefinition", {}).get("resolvedDependencies", []):
            print(f"{indent}from {source['uri'].split('?')[0]}  {source['digest']['sha256'][:12]}")
        started = predicate.get("runDetails", {}).get("metadata", {}).get("startedOn")
        if started:
            print(f"{indent}built {started[:19]}Z")


def configs(root, descriptor):
    """Yield every image config below a descriptor."""
    document = json.loads(blob(root, descriptor["digest"]).read_text())
    if descriptor["mediaType"].endswith("index.v1+json"):
        for child in document["manifests"]:
            yield from configs(root, child)
    elif document["config"]["mediaType"].endswith("config.v1+json"):
        yield json.loads(blob(root, document["config"]["digest"]).read_text())


path = Path(sys.argv[1])
if sys.argv[2:] == ["config"]:
    for top in json.loads((path / "index.json").read_text())["manifests"]:
        for config in configs(path, top):
            settings = config["config"]
            print(json.dumps({k: settings[k] for k in ("Entrypoint", "Cmd", "WorkingDir", "ExposedPorts") if k in settings}))
            print(f"{config['os']}/{config['architecture']}, {len(config['rootfs']['diff_ids'])} layers, "
                  f"{len(config['history'])} history entries")
elif path.is_file():
    for entry in json.loads(path.read_text())["manifests"]:
        show(None, entry)
else:
    for top in json.loads((path / "index.json").read_text())["manifests"]:
        show(path, top)
