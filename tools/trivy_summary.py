"""Summarize a Trivy JSON report: findings by severity, and the packages with the most (lesson 10.2).

    python3 tools/trivy_summary.py report.json
"""
import json
import sys
from collections import Counter

report = json.load(open(sys.argv[1]))
findings = [v for r in report.get("Results", []) for v in (r.get("Vulnerabilities") or [])]
severity = Counter(v["Severity"] for v in findings)
order = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]
os_info = report.get("Metadata", {}).get("OS") or {}
print(f"{os_info.get('Family', '?')} {os_info.get('Name', '')}: {len(findings)} findings, "
      + ", ".join(f"{severity[s]} {s.lower()}" for s in order if severity[s]))
fixable = sum(1 for v in findings if v.get("FixedVersion") and v["Severity"] in ("CRITICAL", "HIGH"))
print(f"critical or high with a fixed version available: {fixable}")
print("scanned: " + ", ".join(f"{r.get('Type')} ({len(r.get('Vulnerabilities') or [])} findings)" for r in report.get("Results", [])))
print("most findings: " + ", ".join(f"{p} ({n})" for p, n in Counter(v["PkgName"] for v in findings).most_common(4)))
