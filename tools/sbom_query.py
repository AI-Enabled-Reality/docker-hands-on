"""Answer questions from an image's SBOM, as BuildKit attaches it (SPDX JSON) (lesson 10.2).

    docker buildx imagetools inspect <image> --format '{{json .SBOM}}' > sbom.json
    python3 tools/sbom_query.py sbom.json             # what kinds of packages, how many
    python3 tools/sbom_query.py sbom.json ssl crypto  # every package whose name contains a term

Each package has a type, from its package URL: deb (Debian packages), pypi (Python packages), and
whatever else the scanner recognized, with the place it found the package.
"""
import json
import sys
from collections import Counter

document = json.load(open(sys.argv[1]))
spdx = document.get("SPDX", document)
packages = spdx["packages"]


def kind(package):
    for ref in package.get("externalRefs", []):
        if ref.get("referenceType") == "purl":
            return ref["referenceLocator"].split("/")[0].removeprefix("pkg:")
    return "other"


terms = [t.lower() for t in sys.argv[2:]]
if not terms:
    print(f"{spdx['spdxVersion']}, made by {', '.join(spdx['creationInfo']['creators'][1:])}")
    print(f"{len(packages)} packages: " + ", ".join(f"{n} {k}" for k, n in Counter(map(kind, packages)).most_common()))
else:
    seen = set()
    for p in sorted(packages, key=lambda p: (kind(p), p["name"])):
        if any(t in p["name"].lower() for t in terms):
            where = p.get("sourceInfo", "").split("following paths: ")[-1].split(",")[0]
            key = (kind(p), p["name"], p.get("versionInfo"), where)
            if key not in seen:
                seen.add(key)
                print(f"{kind(p):<5} {p['name']:<16} {p.get('versionInfo', ''):<18} {where}")
