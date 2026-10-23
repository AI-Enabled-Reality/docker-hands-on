import pytest
from fastapi.testclient import TestClient


@pytest.fixture
def client(monkeypatch):
    # A database nobody listens on: the API must still start and say it isn't ready.
    monkeypatch.setenv("PRICING_DATABASE_URL", "postgresql://pricing@127.0.0.1:1/pricing")
    monkeypatch.setenv("PRICING_DATABASE_CONNECT_TIMEOUT", "1")
    from pricing import db, settings

    settings.get_settings.cache_clear()
    db.close()
    from pricing.api import app

    with TestClient(app) as test_client:
        yield test_client
    db.close()
    settings.get_settings.cache_clear()


def test_alive_without_a_database(client):
    assert client.get("/health/live").json() == {"status": "ok"}


def test_not_ready_without_a_database(client):
    response = client.get("/health/ready")
    assert response.status_code == 503
    assert response.json()["checks"] == {"database": "unreachable"}


def test_version(client):
    body = client.get("/version").json()
    assert body["version"] == "1.0.0"
    assert set(body) == {"version", "build", "python", "hostname"}


def test_quote_rejects_an_unknown_site_format(client):
    assert client.post("/quotes", json={"site_id": "N03", "energy_kwh": 10}).status_code == 422
