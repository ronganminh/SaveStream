from __future__ import annotations

import asyncio
import logging

from app.application.notifications.ports import NotificationMessage
from app.application.operations.service import OperationsService, evaluate_alerts
from app.infrastructure.db.session import Database
from app.infrastructure.notifications.senders import build_notification_sender
from app.infrastructure.redis import RedisClient
from app.settings import get_app_settings

logger = logging.getLogger("savestream.operations.alerts")


async def _check() -> int:
    settings = get_app_settings()
    database = Database(settings.database_url)
    redis = RedisClient(settings.redis_url)
    sent = 0
    try:
        async with database.session() as session:
            snapshot = await OperationsService(session, settings).snapshot()
        sender = build_notification_sender(settings)
        for alert in evaluate_alerts(snapshot, settings):
            key = f"savestream:ops-alert:{alert.code}"
            should_send = True
            try:
                acquired = await redis.client.set(
                    key,
                    "1",
                    ex=settings.ops_alert_cooldown_seconds,
                    nx=True,
                )
                should_send = bool(acquired)
            except Exception:
                logger.exception("alert cooldown storage unavailable code=%s", alert.code)
            if not should_send:
                continue
            await sender.send(
                NotificationMessage(
                    subject=f"[SaveStream] {alert.code}",
                    body=(
                        f"{alert.message}\n"
                        f"value={alert.value}\n"
                        f"threshold={alert.threshold}\n"
                        f"environment={settings.environment}\n"
                    ),
                    severity=alert.severity,
                    dedupe_key=alert.code,
                )
            )
            sent += 1
        return sent
    finally:
        await redis.close()
        await database.close()


def run_ops_alert_check() -> int:
    return asyncio.run(_check())
