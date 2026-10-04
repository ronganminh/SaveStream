from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.admin_models import AdminDailyMetric


class AdminOverviewService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def series(self, *, days: int = 30) -> list[AdminDailyMetric]:
        rows = list(
            (
                await self.session.scalars(
                    select(AdminDailyMetric)
                    .order_by(AdminDailyMetric.day.desc())
                    .limit(days)
                )
            ).all()
        )
        rows.reverse()
        return rows
