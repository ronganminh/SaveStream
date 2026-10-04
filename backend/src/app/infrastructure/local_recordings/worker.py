from __future__ import annotations

import asyncio

from app.application.local_recordings.service import LocalRecordingService
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings


async def _expire(settings: AppSettings) -> int:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            return await LocalRecordingService(
                session,
                settings,
            ).close_expired()
    finally:
        await database.close()


def expire_local_recording_leases() -> int:
    return asyncio.run(_expire(get_app_settings()))
