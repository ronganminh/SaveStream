from __future__ import annotations

import asyncio

from app.application.notifications.b6 import B6NotificationService
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings


async def _run_b6_notification_scan(settings: AppSettings) -> int:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            result = await B6NotificationService(session, settings).scan()
            return result.recording_expiring
    finally:
        await database.close()


def run_b6_notification_scan() -> int:
    return asyncio.run(
        _run_b6_notification_scan(get_app_settings())
    )
