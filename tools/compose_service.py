"""Print one service of a Compose project the way Compose will run it (lessons 9.1 and 9.2).

    docker compose config --format json | python3 tools/compose_service.py api

Shows the image, the Dockerfile, published ports, the environment's variable names (not their values),
secrets, configs and watch rules: what the files merged into, not what one of them says.
"""
import json
import sys

service = json.load(sys.stdin)["services"][sys.argv[1]]
ports = [f'{p.get("host_ip", "")}:{p["published"]}->{p["target"]}' for p in service.get("ports", [])]
watch = [f'{w["action"]} {w["path"].rstrip("/").split("/")[-1]}' for w in service.get("develop", {}).get("watch", [])]
print("image:      ", service.get("image"))
print("dockerfile: ", service.get("build", {}).get("dockerfile", "-") if "build" in service else "-")
print("ports:      ", ", ".join(ports) or "none")
print("environment:", ", ".join(sorted(service.get("environment", {}))) or "none")
print("secrets:    ", ", ".join(s["source"] for s in service.get("secrets", [])) or "none")
print("configs:    ", ", ".join(c["source"] for c in service.get("configs", [])) or "none")
print("watch:      ", ", ".join(watch) or "none")
