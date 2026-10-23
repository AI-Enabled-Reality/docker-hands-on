"""Exercise 6.2: a quote through the proxy on 127.0.0.1:8762 works, and the proxy is the only way in."""
import json
import urllib.error
import urllib.request

import pytest

from common.dockerlab import docker, inspect, require_docker

QUOTE = {"site_id": "site-N03", "energy_kwh": 31.4, "idle_minutes": 6, "on": "2026-10-23"}


def setup_module():
    require_docker()


def test_a_quote_through_the_proxy():
    request = urllib.request.Request("http://127.0.0.1:8762/quotes", data=json.dumps(QUOTE).encode(),
                                     headers={"content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            body, server = json.load(response), response.headers.get("Server", "")
    except urllib.error.HTTPError as error:
        pytest.fail(f"The proxy answered HTTP {error.code}. Keep climbing the ladder.")
    except urllib.error.URLError as error:
        pytest.fail(f"Nothing answers on 127.0.0.1:8762 ({error.reason}). Is m06x2-proxy running and published?")
    assert server.startswith("nginx"), f"The answer came from {server!r}, not from the proxy."
    assert body["amount_eur"] == 15.99, body


def test_the_proxy_is_the_only_entry_point():
    assert inspect("m06x2-proxy")["Config"]["Image"].startswith("nginx:"), "m06x2-proxy should run the nginx image."
    assert docker("port", "m06x2-proxy").splitlines() == ["8080/tcp -> 127.0.0.1:8762"]
    for name in ("m06x2-api", "m06x2-db"):
        assert docker("port", name) == "", f"{name} publishes a port: only the proxy should."
