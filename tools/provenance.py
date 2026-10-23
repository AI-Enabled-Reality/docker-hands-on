"""Print what a provenance attestation records about a build (lessons 10.2 and 10.3).

    docker buildx imagetools inspect <image> --format '{{json .Provenance}}' > provenance.json
    python3 tools/provenance.py provenance.json

Also reads the provenance.json a local exporter writes (docker build --output type=local,dest=…).
"""
import json
import sys

document = json.load(open(sys.argv[1]))
slsa = document.get("SLSA") or document.get("predicate") or document
definition = slsa["buildDefinition"]
print("materials:")
for d in definition.get("resolvedDependencies", []):
    print(f"  {d['uri'].split('?')[0]} {d['digest']['sha256'][:12]}")
args = definition["externalParameters"]["request"].get("args", {})
build_args = [f"{k.removeprefix('build-arg:')}={v}" for k, v in sorted(args.items()) if k.startswith("build-arg:")]
print("build arguments: " + (", ".join(build_args) or "none recorded"))
steps = definition.get("internalParameters", {}).get("buildConfig", {}).get("llbDefinition", [])
print(f"build steps: {len(steps) or 'none recorded'}")
