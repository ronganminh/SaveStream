from __future__ import annotations

import asyncio

from app.application.rewards.retention import prune_reward_intents
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings


async def _run(settings: AppSettings) -> int:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            return await prune_reward_intents(
                session,
                retention_days=settings.reward_retention_days,
                batch_size=settings.reward_retention_batch_size,
            )
    finally:
        await database.close()


def run_reward_retention() -> int:
    return asyncio.run(_run(get_app_settings()))
