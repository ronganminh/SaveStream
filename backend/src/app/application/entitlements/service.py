from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from typing import Literal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.application.rewards.service import cloud_rewards_enabled
from app.application.runtime_settings import RuntimeSettingsService
from app.application.credits.service import CreditService
from app.application.recordings.retention import (
    PAID_ORDER_STATUSES,
    has_paid_purchase,
)
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.local_recording_models import (
    LocalDailyUsage,
    LocalSlotGrant,
    RewardIntent,
)
from app.infrastructure.db.models import User
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
    max_concurrent_sessions: int
    second_slot_expires_at: datetime | None


@dataclass(frozen=True, slots=True)
class AdsEntitlementSnapshot:
    """What the Android app may show: rewarded ads for cloud minutes, and a
    small banner for accounts that never bought a pack."""

    rewarded_available: bool
    rewards_left_today: int
    rewards_cap_per_day: int
    minutes_per_reward: int
    resets_at: datetime
    show_banners: bool


@dataclass(frozen=True, slots=True)
class EntitlementSnapshot:
    plan: EntitlementPlan
    has_purchased: bool
    email_verified: bool
    cloud_minutes_available: int
    # Posted balance: includes credits held for recordings that are running.
    # Plan and Auto-record follow it, so a recording that holds every credit
    # does not flip the account to "out of credit" while it records (QA
    # 2026-10-16). Starting a new recording still needs available credit.
    cloud_minutes_posted: int
    max_watches: int
    max_concurrent_cloud_recordings: int
    cloud_retention_days: int
    watch_count: int
    local: LocalEntitlementSnapshot
    updated_at: datetime
    ads: AdsEntitlementSnapshot | None = None
    # Latest paid (or partly refunded) pack: its name and size.
    last_pack_name: str | None = None
    last_pack_minutes: int | None = None
    # The N in "X minutes left of N": posted minutes right after the latest
    # top-up (pack purchase, else the free trial grant), plus minutes granted
    # since (rewarded ads, promo codes, support grants). Charges only lower
    # the balance, so cloud_minutes_posted <= this. None before any top-up.
    cloud_minutes_cycle_total: int | None = None
    # The one-time free trial grant was ever made (used up or not).
    trial_used: bool = False

    @property
    def is_pro(self) -> bool:
        return self.plan == "pro"

    @property
    def trial_recording(self) -> bool:
        """Not purchased yet, but the free trial credits may record.

        Trial credits are granted once per account, and only accounts with a
        verified email may spend them on cloud recording.
        """
        return (
            not self.has_purchased
            and self.email_verified
            and self.cloud_minutes_posted > 0
        )

    @property
    def can_auto_record(self) -> bool:
        return self.is_pro or self.trial_recording

    @property
    def can_start_recording(self) -> bool:
        """Auto-record is on and some credit is not held by a running recording."""
        return self.can_auto_record and self.cloud_minutes_available > 0

    @property
    def out_of_credit(self) -> bool:
        """Could record, but the credits ran out (trial used up or pack spent)."""
        return (
            not self.can_auto_record
            and self.cloud_minutes_posted <= 0
            and (self.has_purchased or self.email_verified)
        )

    @property
    def manual_cloud_recording_limit(self) -> int:
        # Free accounts may record one cloud job at a time on trial credit.
        return 3 if self.is_pro else 1


class EntitlementService:
    FREE_MAX_WATCHES = 3
    PRO_MAX_WATCHES = 20
    PRO_MAX_CONCURRENT_CLOUD_RECORDINGS = 3
    TRIAL_MAX_CONCURRENT_CLOUD_RECORDINGS = 1

    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def get(self, user_id: uuid.UUID) -> EntitlementSnapshot:
        has_purchased = await has_paid_purchase(self.session, user_id)
        balance = await CreditService(self.session).balance(user_id)
        is_pro = has_purchased and balance.posted > 0
        user = await self.session.get(User, user_id)
        email_verified = user is not None and user.email_verified_at is not None
        trial_recording = (
            not has_purchased and email_verified and balance.posted > 0
        )
        plan: EntitlementPlan = "pro" if is_pro else "free"
        runtime = RuntimeSettingsService(self.session, self.settings)
        pro_local_recording = await runtime.string("pro_local_recording")
        free_local_daily_minutes = await runtime.integer("free_local_daily_minutes")
        reward_daily_cap = await runtime.integer("reward_daily_cap")
        reward_minutes = await runtime.integer("reward_minutes")
        free_max_watches = await runtime.integer("free_max_watches")
        pro_max_watches = await runtime.integer("pro_max_watches")
        pro_max_concurrent = await runtime.integer(
            "pro_max_concurrent_cloud_recordings"
        )
        paid_retention_days = await runtime.integer("recording_retention_days")
        free_retention_days = await runtime.integer("recording_retention_days_free")

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

        usage = await self.session.scalar(
            select(LocalDailyUsage).where(
                LocalDailyUsage.user_id == user_id,
                LocalDailyUsage.usage_day == now.date(),
            )
        )
        used_minutes = usage.used_minutes if usage is not None else 0
        rewards_used_today = int(
            await self.session.scalar(
                select(func.count())
                .select_from(RewardIntent)
                .where(
                    RewardIntent.user_id == user_id,
                    RewardIntent.status == "valid",
                    RewardIntent.verified_at >= datetime.combine(
                        now.date(),
                        time.min,
                        tzinfo=timezone.utc,
                    ),
                    RewardIntent.verified_at < resets_at,
                )
            )
            or 0
        )
        slot_grant = await self.session.scalar(
            select(LocalSlotGrant)
            .where(
                LocalSlotGrant.user_id == user_id,
                LocalSlotGrant.expires_at > now,
            )
            .order_by(LocalSlotGrant.expires_at.desc())
            .limit(1)
        )

        pro_local_enabled = (
            not is_pro
            or pro_local_recording == "unlimited"
        )
        local = LocalEntitlementSnapshot(
            enabled=pro_local_enabled and self.settings.local_recording_enabled,
            unlimited=(
                is_pro
                and pro_local_recording == "unlimited"
            ),
            daily_minutes=free_local_daily_minutes,
            minutes_remaining=max(
                free_local_daily_minutes - used_minutes,
                0,
            ),
            resets_at=resets_at,
            rewards_used_today=rewards_used_today,
            rewards_cap_per_day=reward_daily_cap,
            minutes_per_reward=reward_minutes,
            extensions_cap_per_recording=self.settings.reward_extensions_cap,
            max_concurrent_sessions=2 if slot_grant is not None else 1,
            second_slot_expires_at=(
                slot_grant.expires_at if slot_grant is not None else None
            ),
        )

        cloud_cap = await runtime.integer("reward_cloud_daily_cap")
        cloud_minutes = await runtime.integer("reward_cloud_minutes")
        cloud_used = int(
            await self.session.scalar(
                select(func.count())
                .select_from(RewardIntent)
                .where(
                    RewardIntent.user_id == user_id,
                    RewardIntent.purpose == "cloud_minutes",
                    RewardIntent.status == "valid",
                    RewardIntent.verified_at
                    >= datetime.combine(now.date(), time.min, tzinfo=timezone.utc),
                    RewardIntent.verified_at < resets_at,
                )
            )
            or 0
        )
        rewards_left = max(cloud_cap - cloud_used, 0)
        ads = AdsEntitlementSnapshot(
            rewarded_available=(
                cloud_rewards_enabled(self.settings)
                and email_verified
                and cloud_minutes > 0
                and rewards_left > 0
            ),
            rewards_left_today=rewards_left,
            rewards_cap_per_day=cloud_cap,
            minutes_per_reward=cloud_minutes,
            resets_at=resets_at,
            # Any pack bought (ever) turns banners off for good.
            show_banners=not has_purchased,
        )

        purchase = await self._purchase_summary(user_id)

        return EntitlementSnapshot(
            last_pack_name=purchase.last_pack_name,
            last_pack_minutes=purchase.last_pack_minutes,
            cloud_minutes_cycle_total=purchase.cycle_total,
            trial_used=purchase.trial_used,
            plan=plan,
            has_purchased=has_purchased,
            email_verified=email_verified,
            cloud_minutes_available=balance.available,
            cloud_minutes_posted=balance.posted,
            max_watches=(pro_max_watches if is_pro else free_max_watches),
            max_concurrent_cloud_recordings=(
                pro_max_concurrent
                if is_pro
                else self.TRIAL_MAX_CONCURRENT_CLOUD_RECORDINGS
                if trial_recording
                else 0
            ),
            # Retention follows purchase history, matching the existing backend:
            # accounts that have ever retained a paid order keep cloud files for
            # the paid retention window even after their available balance hits 0.
            cloud_retention_days=(
                paid_retention_days
                if has_purchased
                else (free_retention_days or paid_retention_days)
            ),
            watch_count=watch_count,
            local=local,
            updated_at=now,
            ads=ads,
        )

    async def _purchase_summary(self, user_id: uuid.UUID) -> _PurchaseSummary:
        last_pack = (
            await self.session.execute(
                select(CreditPackage.name, PaymentOrder.credits)
                .join(CreditPackage, CreditPackage.id == PaymentOrder.package_id)
                .where(
                    PaymentOrder.user_id == user_id,
                    PaymentOrder.status.in_(PAID_ORDER_STATUSES),
                )
                .order_by(
                    func.coalesce(PaymentOrder.paid_at, PaymentOrder.created_at).desc(),
                    PaymentOrder.created_at.desc(),
                )
                .limit(1)
            )
        ).first()
        trial_used = (
            await self.session.scalar(
                select(CreditLedgerEntry.id)
                .where(
                    CreditLedgerEntry.user_id == user_id,
                    CreditLedgerEntry.reference_type == "signup_bonus",
                )
                .limit(1)
            )
        ) is not None
        anchor = await self.session.scalar(
            select(CreditLedgerEntry)
            .where(
                CreditLedgerEntry.user_id == user_id,
                CreditLedgerEntry.entry_type == "grant",
                CreditLedgerEntry.amount > 0,
                CreditLedgerEntry.reference_type.in_(_TOP_UP_REFERENCE_TYPES),
            )
            .order_by(CreditLedgerEntry.created_at.desc(), CreditLedgerEntry.id.desc())
            .limit(1)
        )
        cycle_total: int | None = None
        if anchor is not None:
            anchor_entry = aliased(CreditLedgerEntry)
            granted_since = int(
                await self.session.scalar(
                    select(func.coalesce(func.sum(CreditLedgerEntry.amount), 0)).where(
                        CreditLedgerEntry.user_id == user_id,
                        CreditLedgerEntry.amount > 0,
                        CreditLedgerEntry.id != anchor.id,
                        # Ties count as later: overstating N is harmless,
                        # understating it would let the balance exceed it.
                        # Compared in SQL, against the stored value.
                        CreditLedgerEntry.created_at
                        >= select(anchor_entry.created_at)
                        .where(anchor_entry.id == anchor.id)
                        .scalar_subquery(),
                    )
                )
                or 0
            )
            cycle_total = max(anchor.balance_after, 0) + granted_since
        return _PurchaseSummary(
            last_pack_name=last_pack[0] if last_pack is not None else None,
            last_pack_minutes=int(last_pack[1]) if last_pack is not None else None,
            cycle_total=cycle_total,
            trial_used=trial_used,
        )


# Ledger grants that start a new "minutes left of N" cycle.
_TOP_UP_REFERENCE_TYPES = ("payment_order", "signup_bonus")


@dataclass(frozen=True, slots=True)
class _PurchaseSummary:
    last_pack_name: str | None
    last_pack_minutes: int | None
    cycle_total: int | None
    trial_used: bool
