from __future__ import annotations

import asyncio

from app.application.privacy.service import PrivacyService
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings


async def _run(settings: AppSettings) -> dict[str, int]:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            service = PrivacyService(session)
            retained = await service.apply_recording_retention(settings)
            deleted = await service.anonymize_due_accounts(settings)
            pruned = await service.prune_ephemeral()
            await session.commit()
            return {
                "recordings_retained": retained,
                "accounts_anonymized": deleted,
                "ephemeral_rows_pruned": pruned,
            }
    finally:
        await database.close()


def run_privacy_retention() -> dict[str, int]:
    return asyncio.run(_run(get_app_settings()))
