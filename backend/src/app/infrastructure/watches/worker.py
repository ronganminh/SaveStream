from __future__ import annotations

import asyncio
import uuid

from app.api.schemas.recordings import Source
from app.application.watches.scheduler import WatchClaim, WatchLiveResult, WatchScheduler
from app.infrastructure.db.session import Database
from app.infrastructure.recording.runtime import build_recording_runtime
from app.settings import AppSettings, get_app_settings


class RuntimeWatchChecker:
    def __init__(self, settings: AppSettings) -> None:
        self._resolver = build_recording_runtime(settings).resolver

    async def check(self, source: Source) -> WatchLiveResult:
        resolved, is_live = await asyncio.to_thread(
            self._resolver.live_status,
            source,
        )
        return WatchLiveResult(
            username=resolved.username,
            room_id=resolved.room_id,
            is_live=is_live,
        )


async def _claim_due(settings: AppSettings) -> list[WatchClaim]:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            return await WatchScheduler(session, settings).claim_due()
    finally:
        await database.close()


async def _check(
    watch_id: uuid.UUID,
    lease_id: uuid.UUID,
    settings: AppSettings,
) -> None:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            await WatchScheduler(session, settings).process_claim(
                WatchClaim(watch_id=watch_id, lease_id=lease_id),
                RuntimeWatchChecker(settings),
            )
    finally:
        await database.close()


def run_watch_scheduler_tick() -> list[tuple[str, str]]:
    claims = asyncio.run(_claim_due(get_app_settings()))
    return [(str(item.watch_id), str(item.lease_id)) for item in claims]


def run_watch_check(watch_id: str, lease_id: str) -> None:
    asyncio.run(
        _check(
            uuid.UUID(watch_id),
            uuid.UUID(lease_id),
            get_app_settings(),
        )
    )
