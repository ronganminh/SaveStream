from __future__ import annotations

import asyncio

from app.application.notifications.push import PushDeliveryService
from app.infrastructure.db.session import Database
from app.infrastructure.push.factory import selected_push_sender
from app.settings import AppSettings, get_app_settings


async def deliver_notification_push(
    notification_id: str,
    settings: AppSettings | None = None,
) -> int:
    cfg = settings or get_app_settings()
    database = Database(cfg.database_url)
    try:
        async with database.session() as session:
            return await PushDeliveryService(
                session,
                selected_push_sender(cfg),
            ).deliver(notification_id)
    finally:
        await database.close()


def run_notification_push(notification_id: str) -> int:
    return asyncio.run(deliver_notification_push(notification_id))
