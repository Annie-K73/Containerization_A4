import json
import os
from datetime import UTC, datetime


bind = "0.0.0.0:8000"
workers = int(os.getenv("WEB_CONCURRENCY", "2"))
worker_class = "sync"
timeout = 30
graceful_timeout = 25
keepalive = 5
accesslog = None  # Flask emits one structured request_complete event per request.
errorlog = "-"
capture_output = True
worker_tmp_dir = "/tmp"
max_requests = 1_000
max_requests_jitter = 100


def _event(name: str, **fields: object) -> None:
    payload = {
        "timestamp": datetime.now(UTC).isoformat(),
        "level": "INFO",
        "service": "delivery-api",
        "logger": "gunicorn.lifecycle",
        "event": name,
        **fields,
    }
    print(json.dumps(payload, separators=(",", ":")), flush=True)


def when_ready(server) -> None:  # Gunicorn hook signature
    _event("gunicorn_ready", pid=server.pid)


def worker_int(worker) -> None:  # Gunicorn sends SIGINT/SIGTERM during shutdown
    _event("worker_shutdown_requested", pid=worker.pid)


def worker_exit(server, worker) -> None:
    _event("worker_exited", pid=worker.pid)
