from __future__ import annotations

import asyncio
import logging
from typing import Any

from .celery_app import celery_app

logger = logging.getLogger("savestream.worker")


@celery_app.task(name="savestream.health.ping")
def health_ping() -> str:
    return "pong"


@celery_app.task(
    bind=True,
    name="savestream.outbox.event",
    autoretry_for=(Exception,),
    retry_backoff=True,
    retry_jitter=True,
    max_retries=5,
)
def handle_outbox_event(
    self,
    *,
    event_id: str,
    topic: str,
    payload: dict[str, Any],
) -> None:
    del self
    if topic in {"identity.email.verify_email", "identity.email.password_reset"}:
        from app.infrastructure.email.smtp import deliver_one_time_token_email

        token_id = str(payload.get("token_id", ""))
        asyncio.run(deliver_one_time_token_email(token_id))
        return

    logger.info("outbox event handled id=%s topic=%s", event_id, topic)
