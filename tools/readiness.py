"""Check a running Compose project against the course's production-readiness checklist (lesson 11.2).

    python3 tools/readiness.py <project> [--own brightlane/]

Every check reads what Docker reports about the project's containers (docker inspect), so it checks
what actually runs, not what a file says. Containers that ran to completion (exit code 0, no restart
policy) are jobs, such as the migration: only the image and secret checks apply to them. "Own" images,
the ones you build (by default, any image with brightlane/ in its name), get the stricter checks.
Exit code 0 when every check passes, 1 otherwise.
"""
import argparse
import json
import re
import subprocess
import sys

SECRET_NAME = re.compile(r"PASSWORD|SECRET|TOKEN|API_?KEY", re.I)


def inspect_project(project):
    ids = subprocess.run(["docker", "ps", "-aq", "--filter", f"label=com.docker.compose.project={project}"],
                         capture_output=True, text=True, check=True).stdout.split()
    if not ids:
        sys.exit(f"No containers in the Compose project {project!r}. Is it up?")
    containers = json.loads(subprocess.run(["docker", "inspect", *ids], capture_output=True, text=True, check=True).stdout)
    images = {c["Image"]: json.loads(subprocess.run(["docker", "image", "inspect", c["Image"]], capture_output=True,
                                                    text=True).stdout or "[{}]")[0] for c in containers}
    return sorted(containers, key=lambda c: c["Name"]), images


def service(c):
    return c["Config"]["Labels"].get("com.docker.compose.service", c["Name"].lstrip("/"))


def is_job(c):
    return (not c["State"]["Running"] and c["State"]["ExitCode"] == 0
            and c["HostConfig"]["RestartPolicy"]["Name"] in ("", "no"))


def checks(containers, images, own):
    running = [c for c in containers if not is_job(c)]
    mine = [c for c in running if own in c["Config"]["Image"]]

    def each(items, problem):
        return [f"{service(c)}: {p}" for c in items if (p := problem(c))]

    yield "running and healthy", each(running, lambda c: (
        f"not running ({c['State']['Status']}, exit code {c['State']['ExitCode']})" if not c["State"]["Running"]
        else f"health {c['State']['Health']['Status']}" if c["State"].get("Health", {}).get("Status", "healthy") != "healthy"
        else None))
    yield "image pinned to a version", each(containers, lambda c: (
        None if "@sha256:" in c["Config"]["Image"] or re.search(r":[^/:]*\d+\.\d+[^/:]*$", c["Config"]["Image"])
        else f"{c['Config']['Image']} (use an exact version tag or a digest)"))
    yield "own images traceable", each(mine, lambda c: (
        None if (images[c["Image"]].get("Config", {}).get("Labels") or {}).get("org.opencontainers.image.source")
        else "no org.opencontainers.image.source label"))
    yield "own images not root", each(mine, lambda c: (
        f"runs as {c['Config']['User'] or 'root'}" if c["Config"]["User"] in ("", "root", "0", "0:0") else None))
    yield "own images locked down", each(mine, lambda c: ", ".join(p for p in (
        "writable root filesystem" if not c["HostConfig"]["ReadonlyRootfs"] else "",
        "capabilities not dropped" if "ALL" not in (c["HostConfig"]["CapDrop"] or []) else "",
        "no no-new-privileges" if not any(o.startswith("no-new-privileges") for o in c["HostConfig"]["SecurityOpt"] or []) else "",
    ) if p) or None)
    yield "nothing that escapes the container", each(containers, lambda c: ", ".join(p for p in (
        "privileged" if c["HostConfig"]["Privileged"] else "",
        "Docker socket mounted" if any(m.get("Source", "").endswith("docker.sock") for m in c["Mounts"]) else "",
        "unconfined profile" if any("unconfined" in o for o in c["HostConfig"]["SecurityOpt"] or []) else "",
        "host network" if c["HostConfig"]["NetworkMode"] == "host" else "",
        "host PID namespace" if c["HostConfig"]["PidMode"] == "host" else "",
    ) if p) or None)
    yield "healthcheck", each(running, lambda c: (
        None if (c["Config"].get("Healthcheck") or {}).get("Test", ["NONE"])[0] != "NONE" else "none"))
    yield "restart policy", each(running, lambda c: (
        None if c["HostConfig"]["RestartPolicy"]["Name"] in ("unless-stopped", "always", "on-failure")
        else f"restart: {c['HostConfig']['RestartPolicy']['Name'] or 'no'}"))
    yield "memory limit", each(running, lambda c: None if c["HostConfig"]["Memory"] else "none")
    yield "log rotation set explicitly", each(running, lambda c: (
        None if c["HostConfig"]["LogConfig"]["Type"] in ("local", "json-file") and "max-size" in c["HostConfig"]["LogConfig"]["Config"]
        else f"{c['HostConfig']['LogConfig']['Type']} {c['HostConfig']['LogConfig']['Config'] or 'without max-size'}"))
    publishing = [c for c in running if any(c["NetworkSettings"]["Ports"].get(p) for p in c["NetworkSettings"]["Ports"] or {})]
    yield "one published entry point", ([] if len(publishing) <= 1 else [
        f"{service(c)}: " + ", ".join(f"{b['HostIp'] or '0.0.0.0'}:{b['HostPort']}->{p}"
                                       for p, bs in c["NetworkSettings"]["Ports"].items() if bs for b in bs)
        for c in publishing])
    yield "no anonymous volumes", each(running, lambda c: ", ".join(
        f"{m['Destination']}" for m in c["Mounts"] if m["Type"] == "volume" and re.fullmatch(r"[0-9a-f]{64}", m.get("Name", ""))) or None)
    yield "no secrets in the environment", each(containers, lambda c: ", ".join(
        e.split("=", 1)[0] for e in c["Config"]["Env"] or []
        if SECRET_NAME.search(e.split("=", 1)[0]) and not e.split("=", 1)[0].endswith("_FILE")) or None)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("project")
    parser.add_argument("--own", default="brightlane/", help="text in the names of the images you build")
    args = parser.parse_args()
    containers, images = inspect_project(args.project)
    jobs = [service(c) for c in containers if is_job(c)]
    print(f"project {args.project}: {len(containers)} containers" + (f" ({', '.join(jobs)} ran as a job)" if jobs else ""))
    failed = 0
    results = list(checks(containers, images, args.own))
    for name, problems in results:
        print(f"{'FAIL' if problems else 'pass'}  {name}")
        for problem in problems:
            print(f"        {problem}")
        failed += bool(problems)
    print(f"{len(results) - failed} of {len(results)} checks pass")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
