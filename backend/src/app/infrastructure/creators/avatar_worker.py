from __future__ import annotations

import asyncio

from app.application.creators.avatar_cache import CreatorAvatarCache
from app.infrastructure.creators.avatar_fetch import download_avatar
from app.infrastructure.db.session import Database
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings, get_app_settings


async def _refresh(settings: AppSettings) -> int:
    lookup = None
    if settings.environment == "production":
        from app.infrastructure.creators.tiktok_profile import TikTokCreatorMetadataLookup

        lookup = TikTokCreatorMetadataLookup()
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            cache = CreatorAvatarCache(
                session,
                settings,
                MinioStorageClient(settings),
                download_avatar,
                lookup,
            )
            # Copies of deleted channels go first (also covers account deletion).
            await cache.remove_deleted()
            return await cache.refresh_due()
    finally:
        await database.close()


def run_creator_avatar_refresh() -> int:
    return asyncio.run(_refresh(get_app_settings()))
