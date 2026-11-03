from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def _read_secret(file_variable: str, value_variable: str) -> str:
    secret_path = os.getenv(file_variable, "").strip()
    if secret_path:
        path = Path(secret_path)
        if not path.is_file():
            raise RuntimeError(f"{file_variable} does not reference a regular file")
        value = path.read_text(encoding="utf-8").strip()
        if not value:
            raise RuntimeError(f"{file_variable} references an empty file")
        return value

    value = os.getenv(value_variable, "")
    if value:
        return value
    raise RuntimeError(f"Set {file_variable}; {value_variable} is only a local fallback")


@dataclass(frozen=True)
class Settings:
    application_name: str
    app_version: str
    git_sha: str
    environment: str
    log_level: str
    database_host: str
    database_port: int
    postgres_db: str
    postgres_user: str
    postgres_password: str

    @classmethod
    def from_environment(cls) -> "Settings":
        port = int(os.getenv("DATABASE_PORT", "5432"))
        if not 1 <= port <= 65_535:
            raise RuntimeError("DATABASE_PORT must be between 1 and 65535")

        return cls(
            application_name="delivery-api",
            app_version=os.getenv("APP_VERSION", "0.0.0-dev"),
            git_sha=os.getenv("GIT_SHA", "unknown"),
            environment=os.getenv("APP_ENVIRONMENT", "course-lab"),
            log_level=os.getenv("LOG_LEVEL", "INFO").upper(),
            database_host=os.getenv("DATABASE_HOST", "postgres"),
            database_port=port,
            postgres_db=os.getenv("POSTGRES_DB", "delivery"),
            postgres_user=os.getenv("POSTGRES_USER", "delivery"),
            postgres_password=_read_secret(
                "POSTGRES_PASSWORD_FILE",
                "POSTGRES_PASSWORD",
            ),
        )
