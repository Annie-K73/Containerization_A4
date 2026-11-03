from pathlib import Path

import pytest

from app.config import Settings


def test_secret_file_takes_precedence(monkeypatch, tmp_path: Path):
    secret = tmp_path / "postgres_password"
    secret.write_text("from-file\n", encoding="utf-8")
    monkeypatch.setenv("POSTGRES_PASSWORD_FILE", str(secret))
    monkeypatch.setenv("POSTGRES_PASSWORD", "from-environment")
    settings = Settings.from_environment()
    assert settings.postgres_password == "from-file"


def test_missing_secret_is_rejected(monkeypatch):
    monkeypatch.delenv("POSTGRES_PASSWORD_FILE", raising=False)
    monkeypatch.delenv("POSTGRES_PASSWORD", raising=False)
    with pytest.raises(RuntimeError, match="POSTGRES_PASSWORD_FILE"):
        Settings.from_environment()


def test_invalid_database_port_is_rejected(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "local-test")
    monkeypatch.setenv("DATABASE_PORT", "70000")
    with pytest.raises(RuntimeError, match="DATABASE_PORT"):
        Settings.from_environment()

