"""Keep the downloader's Redis copy of the blocklist in step with the
database: once when the API starts, then every few minutes."""

from __future__ import annotations

import asyncio
import logging

from app.application.video_downloader.blocklist import RedisSetClient, sync_to_redis
from app.infrastructure.db.session import Database

logger = logging.getLogger(__name__)
SYNC_INTERVAL_SECONDS = 300


async def sync_video_download_blocklist_forever(
    database: Database, redis: RedisSetClient, interval: float = SYNC_INTERVAL_SECONDS
) -> None:
    while True:
        try:
            async with database.session() as session:
                count = await sync_to_redis(session, redis)
            logger.info("video downloader blocklist synced count=%d", count)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("video downloader blocklist sync failed")
        await asyncio.sleep(interval)
