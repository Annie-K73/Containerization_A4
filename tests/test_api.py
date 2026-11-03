from app import database


def test_health_is_process_only(client, monkeypatch):
    def fail_if_called(_settings):
        raise AssertionError("healthz must not query PostgreSQL")

    monkeypatch.setattr(database, "check_database", fail_if_called)
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.get_json() == {
        "application": "delivery-api",
        "status": "ok",
    }


def test_ready_reports_database_state(client, monkeypatch):
    monkeypatch.setattr(database, "check_database", lambda _settings: True)
    ready = client.get("/readyz")
    assert ready.status_code == 200
    assert ready.get_json()["status"] == "ready"

    monkeypatch.setattr(database, "check_database", lambda _settings: False)
    unavailable = client.get("/readyz")
    assert unavailable.status_code == 503
    assert unavailable.get_json()["status"] == "not_ready"


def test_version_exposes_release_identity_without_secrets(client):
    response = client.get("/version")
    assert response.status_code == 200
    payload = response.get_json()
    assert payload == {
        "application": "delivery-api",
        "environment": "test",
        "git_sha": "abc123def456",
        "version": "1.2.3",
    }
    assert "password" not in response.get_data(as_text=True).lower()


def test_item_lifecycle(client, monkeypatch):
    item = {"id": 7, "name": "evidence marker", "created_at": "2026-01-01T00:00:00Z"}
    monkeypatch.setattr(database, "create_item", lambda _settings, _name: item)
    monkeypatch.setattr(database, "get_item", lambda _settings, _item_id: item)
    monkeypatch.setattr(database, "list_items", lambda _settings: [item])

    created = client.post("/api/items", json={"name": "evidence marker"})
    assert created.status_code == 201
    assert created.get_json()["id"] == 7

    listed = client.get("/api/items")
    assert listed.status_code == 200
    assert listed.get_json()["items"] == [item]

    fetched = client.get("/api/items/7")
    assert fetched.status_code == 200
    assert fetched.get_json() == item


def test_item_input_is_bounded(client):
    assert client.post("/api/items", json={}).status_code == 400
    assert client.post("/api/items", json={"name": ""}).status_code == 400
    assert client.post("/api/items", json={"name": "x" * 121}).status_code == 400


def test_unknown_route_preserves_http_404(client):
    response = client.get("/does-not-exist")
    assert response.status_code == 404
    assert "internal_error" not in response.get_data(as_text=True)
