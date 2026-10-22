"""Retention for rewarded-ad intents.

reward_intents rows hold the app install id (``device_id``) and the AdMob
transaction id. They are only needed for the UTC-day caps, the 1-hour intent
rate limit and the 30-day shared-device alert, so rows older than
``reward_retention_days`` (default 365) are deleted in batches.

The credits a reward granted are untouched: credit_ledger_entries refer to a
reward only by the string ``reference_id`` / ``reference_key`` (no foreign
key), so deleting the intent leaves the ledger row and balance intact.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.local_recording_models import RewardIntent


async def prune_reward_intents(
    session: AsyncSession,
    *,
    retention_days: int,
    batch_size: int,
    now: datetime | None = None,
) -> int:
    """Delete reward intents created more than ``retention_days`` ago.

    Commits after each batch so a large backlog never holds one long
    transaction. Returns the number of rows deleted.
    """
    cutoff = (now or datetime.now(timezone.utc)) - timedelta(days=retention_days)
    deleted = 0
    while True:
        ids = list(
            (
                await session.scalars(
                    select(RewardIntent.id)
                    .where(RewardIntent.created_at < cutoff)
                    .order_by(RewardIntent.created_at)
                    .limit(batch_size)
                )
            ).all()
        )
        if not ids:
            return deleted
        await session.execute(delete(RewardIntent).where(RewardIntent.id.in_(ids)))
        await session.commit()
        deleted += len(ids)
        if len(ids) < batch_size:
            return deleted
