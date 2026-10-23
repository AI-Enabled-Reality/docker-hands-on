"""Build a pure-Python wheel from one package folder, with nothing but the standard library (lesson 10.3).

    python3 tools/make_wheel.py <package folder> <distribution name> <version> <output folder>

A wheel is a zip file: the package's files, plus METADATA, WHEEL and RECORD in a .dist-info folder.
"""
import base64
import hashlib
import sys
import zipfile
from pathlib import Path

source, name, version, out = Path(sys.argv[1]), sys.argv[2], sys.argv[3], Path(sys.argv[4])
stem = f"{name.replace('-', '_')}-{version}"
info = f"{stem}.dist-info"
files = {f"{source.name}/{p.relative_to(source)}": p.read_bytes() for p in sorted(source.rglob("*.py"))}
files[f"{info}/METADATA"] = f"Metadata-Version: 2.1\nName: {name}\nVersion: {version}\n".encode()
files[f"{info}/WHEEL"] = b"Wheel-Version: 1.0\nGenerator: make_wheel.py\nRoot-Is-Purelib: true\nTag: py3-none-any\n"
record = []
for path, data in files.items():
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=").decode()
    record.append(f"{path},sha256={digest},{len(data)}")
record.append(f"{info}/RECORD,,")
files[f"{info}/RECORD"] = ("\n".join(record) + "\n").encode()
out.mkdir(parents=True, exist_ok=True)
wheel = out / f"{stem}-py3-none-any.whl"
with zipfile.ZipFile(wheel, "w", zipfile.ZIP_DEFLATED) as z:
    for path, data in files.items():
        z.writestr(path, data)
print(wheel)
