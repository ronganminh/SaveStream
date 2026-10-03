from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.credits.service import CreditService
from app.application.recordings.retention import has_paid_purchase
from app.infrastructure.db.watch_models import Watch
from app.settings import AppSettings

EntitlementPlan = Literal["free", "pro"]


@dataclass(frozen=True, slots=True)
class LocalEntitlementSnapshot:
    enabled: bool
    unlimited: bool
    daily_minutes: int
    minutes_remaining: int
    resets_at: datetime
    rewards_used_today: int
    rewards_cap_per_day: int
    minutes_per_reward: int
    extensions_cap_per_recording: int


@dataclass(frozen=True, slots=True)
class EntitlementSnapshot:
    plan: EntitlementPlan
    has_purchased: bool
    cloud_minutes_available: int
    max_watches: int
    max_concurrent_cloud_recordings: int
    cloud_retention_days: int
    watch_count: int
    local: LocalEntitlementSnapshot
    updated_at: datetime

    @property
    def is_pro(self) -> bool:
        return self.plan == "pro"

    @property
    def manual_cloud_recording_limit(self) -> int:
        # Free web accounts retain the V1 trial recording path. Mobile Free does
        # not expose cloud recording, but one manual cloud job remains allowed
        # for backwards compatibility while trial credit is available.
        return 3 if self.is_pro else 1


class EntitlementService:
    FREE_MAX_WATCHES = 3
    PRO_MAX_WATCHES = 20
    PRO_MAX_CONCURRENT_CLOUD_RECORDINGS = 3

    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def get(self, user_id: uuid.UUID) -> EntitlementSnapshot:
        has_purchased = await has_paid_purchase(self.session, user_id)
        balance = await CreditService(self.session).balance(user_id)
        is_pro = has_purchased and balance.available > 0
        plan: EntitlementPlan = "pro" if is_pro else "free"

        watch_count = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Watch)
                .where(
                    Watch.user_id == user_id,
                    Watch.deleted_at.is_(None),
                )
            )
            or 0
        )

        now = datetime.now(timezone.utc)
        tomorrow = now.date() + timedelta(days=1)
        resets_at = datetime.combine(tomorrow, time.min, tzinfo=timezone.utc)

        # B1 freezes a safe/default local block. B4 replaces these counters with
        # the real daily-minute and rewarded-ad ledger. The Pro unlimited flag
        # already reflects the locked V2 product decision.
        local = LocalEntitlementSnapshot(
            enabled=True,
            unlimited=is_pro,
            daily_minutes=10,
            minutes_remaining=10,
            resets_at=resets_at,
            rewards_used_today=0,
            rewards_cap_per_day=8,
            minutes_per_reward=10,
            extensions_cap_per_recording=4,
        )

        return EntitlementSnapshot(
            plan=plan,
            has_purchased=has_purchased,
            cloud_minutes_available=balance.available,
            max_watches=(
                self.PRO_MAX_WATCHES if is_pro else self.FREE_MAX_WATCHES
            ),
            max_concurrent_cloud_recordings=(
                self.PRO_MAX_CONCURRENT_CLOUD_RECORDINGS if is_pro else 0
            ),
            # Retention follows purchase history, matching the existing backend:
            # accounts that have ever retained a paid order keep cloud files for
            # the paid retention window even after their available balance hits 0.
            cloud_retention_days=30 if has_purchased else 7,
            watch_count=watch_count,
            local=local,
            updated_at=now,
        )
