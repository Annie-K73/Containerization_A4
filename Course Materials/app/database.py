from __future__ import annotations

from typing import Any

import psycopg
from psycopg.rows import dict_row

from .config import Settings


def _connection_parameters(settings: Settings) -> dict[str, Any]:
    return {
        "host": settings.database_host,
        "port": settings.database_port,
        "dbname": settings.postgres_db,
        "user": settings.postgres_user,
        "password": settings.postgres_password,
        "connect_timeout": 3,
        "application_name": settings.application_name,
        "row_factory": dict_row,
    }


def check_database(settings: Settings) -> bool:
    try:
        with psycopg.connect(**_connection_parameters(settings)) as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                cursor.fetchone()
        return True
    except psycopg.Error:
        return False


def list_items(settings: Settings) -> list[dict[str, Any]]:
    with psycopg.connect(**_connection_parameters(settings)) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, name, created_at FROM items ORDER BY id ASC LIMIT 200"
            )
            return list(cursor.fetchall())


def get_item(settings: Settings, item_id: int) -> dict[str, Any] | None:
    with psycopg.connect(**_connection_parameters(settings)) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT id, name, created_at FROM items WHERE id = %s",
                (item_id,),
            )
            return cursor.fetchone()


def create_item(settings: Settings, name: str) -> dict[str, Any]:
    with psycopg.connect(**_connection_parameters(settings)) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO items (name) VALUES (%s) RETURNING id, name, created_at",
                (name,),
            )
            item = cursor.fetchone()
        connection.commit()
    assert item is not None
    return item
