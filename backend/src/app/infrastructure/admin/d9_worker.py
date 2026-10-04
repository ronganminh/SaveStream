from __future__ import annotations

import asyncio

from app.application.admin.overview_d9 import AdminOverviewService
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings


async def _run(settings: AppSettings) -> dict[str, int | str]:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            service = AdminOverviewService(session)
            row = await service.compute_daily()
            purged = await service.purge_expired_support_reports()
            await session.commit()
            return {
                "day": row.day.isoformat(),
                "support_reports_purged": purged,
            }
    finally:
        await database.close()


def run_d9_rollup() -> dict[str, int | str]:
    return asyncio.run(_run(get_app_settings()))
