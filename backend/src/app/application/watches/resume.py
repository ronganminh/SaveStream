from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.watches.state import WatchStatus
from app.infrastructure.db.watch_models import Watch

from .service import utcnow


async def resume_credit_paused_watches(
    session: AsyncSession,
    user_id: uuid.UUID,
) -> int:
    """Reactivate Watches after verified purchase credit has been posted."""

    rows = list(
        (
            await session.scalars(
                select(Watch)
                .where(
                    Watch.user_id == user_id,
                    Watch.deleted_at.is_(None),
                    Watch.status == WatchStatus.PAUSED_INSUFFICIENT_CREDIT.value,
                )
                .with_for_update()
            )
        ).all()
    )
    now = utcnow()
    for watch in rows:
        watch.status = WatchStatus.ACTIVE.value
        watch.failure_count = 0
        watch.last_error = None
        watch.next_check_at = now
        watch.scheduler_lease_id = None
        watch.scheduler_lease_expires_at = None
    if rows:
        await session.flush()
    return len(rows)
