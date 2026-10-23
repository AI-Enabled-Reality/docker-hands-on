"""Fetch Brightlane's tariff rulebook during a build and save it as /app/rulebook.json (lesson 4.4).

The token comes from a file named on the command line, or from the RULEBOOK_TOKEN environment
variable.
"""
import json
import os
import sys
import urllib.request

token = (open(sys.argv[1]).read() if len(sys.argv) > 1 else os.environ["RULEBOOK_TOKEN"]).strip()
request = urllib.request.Request("http://host.docker.internal:8799/rulebook.json",
                                 headers={"Authorization": f"Bearer {token}"})
with urllib.request.urlopen(request, timeout=10) as response:
    rulebook = json.load(response)
with open("/app/rulebook.json", "w") as f:
    json.dump(rulebook, f, indent=2)
print(f"rulebook {rulebook['version']}: {len(rulebook['rules'])} rules saved")
