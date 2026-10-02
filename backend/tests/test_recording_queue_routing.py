from __future__ import annotations

from dataclasses import replace

from app.infrastructure.queue.celery_app import create_celery_app
from tests.identity_helpers import identity_settings


def _route(settings, task_name: str) -> str | None:
    app = create_celery_app(settings)
    route = app.conf.task_routes.get(task_name)
    return route["queue"] if route else None


def test_recordings_use_the_default_queue_unless_configured() -> None:
    settings = identity_settings("sqlite+aiosqlite:///:memory:")
    assert _route(settings, "savestream.recording.run") == "celery"


def test_recordings_route_to_a_dedicated_queue() -> None:
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        recording_queue="recordings",
    )
    assert _route(settings, "savestream.recording.run") == "recordings"
    # Watch checks and other short tasks stay on the shared worker queue.
    assert _route(settings, "savestream.watch.check") is None
