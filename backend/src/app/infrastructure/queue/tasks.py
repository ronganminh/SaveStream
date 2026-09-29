from __future__ import annotations

import logging
from typing import Any

from .celery_app import celery_app

logger = logging.getLogger("savestream.worker")


@celery_app.task(name="savestream.health.ping")
def health_ping() -> str:
    return "pong"


@celery_app.task(name="savestream.outbox.event")
def handle_outbox_event(
    *, event_id: str, topic: str, payload: dict[str, Any]
) -> None:
    logger.info("outbox event dispatched id=%s topic=%s payload=%s", event_id, topic, payload)
