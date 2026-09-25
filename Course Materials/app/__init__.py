from __future__ import annotations

import time
import uuid

from flask import Flask, g, jsonify, request
from werkzeug.exceptions import BadRequest, HTTPException

from . import database
from .config import Settings
from .logging_config import configure_logging


def create_app(settings: Settings | None = None) -> Flask:
    settings = settings or Settings.from_environment()
    configure_logging(settings.log_level)

    app = Flask(__name__)
    app.config.update(
        MAX_CONTENT_LENGTH=16 * 1024,
        SETTINGS=settings,
    )

    @app.before_request
    def start_request() -> None:
        supplied = request.headers.get("X-Request-ID", "")
        g.request_id = supplied[:128] if supplied.isprintable() else ""
        if not g.request_id:
            g.request_id = str(uuid.uuid4())
        g.started_at = time.monotonic()

    @app.after_request
    def record_request(response):
        duration_ms = round((time.monotonic() - g.started_at) * 1_000, 2)
        app.logger.info(
            "request_complete",
            extra={
                "event": "request_complete",
                "request_id": g.request_id,
                "method": request.method,
                "path": request.path,
                "status": response.status_code,
                "duration_ms": duration_ms,
            },
        )
        response.headers["X-Request-ID"] = g.request_id
        return response

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok", application=settings.application_name)

    @app.get("/readyz")
    def readyz():
        if database.check_database(settings):
            return jsonify(status="ready", dependency="postgres")
        app.logger.warning(
            "readiness_failed",
            extra={"event": "readiness_failed", "dependency": "postgres"},
        )
        return jsonify(status="not_ready", dependency="postgres"), 503

    @app.get("/version")
    def version():
        return jsonify(
            application=settings.application_name,
            version=settings.app_version,
            git_sha=settings.git_sha,
            environment=settings.environment,
        )

    @app.get("/api/items")
    def list_items():
        return jsonify(items=database.list_items(settings))

    @app.post("/api/items")
    def create_item():
        payload = request.get_json(silent=False)
        if not isinstance(payload, dict):
            raise BadRequest("JSON object required")
        name = payload.get("name")
        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 120:
            raise BadRequest("name must contain between 1 and 120 characters")
        item = database.create_item(settings, name.strip())
        return jsonify(item), 201

    @app.get("/api/items/<int:item_id>")
    def get_item(item_id: int):
        item = database.get_item(settings, item_id)
        if item is None:
            return jsonify(error="not_found"), 404
        return jsonify(item)

    @app.errorhandler(BadRequest)
    def bad_request(error: BadRequest):
        return jsonify(error="bad_request", message=error.description), 400

    @app.errorhandler(413)
    def payload_too_large(_error):
        return jsonify(error="payload_too_large"), 413

    @app.errorhandler(Exception)
    def unexpected_error(error: Exception):
        if isinstance(error, HTTPException):
            return error
        app.logger.exception(
            "unhandled_request_error",
            extra={"event": "unhandled_request_error"},
        )
        return jsonify(error="internal_error"), 500

    return app
