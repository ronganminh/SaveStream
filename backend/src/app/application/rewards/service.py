from __future__ import annotations

import math
import uuid
from datetime import datetime, time, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.local_recordings import CreateRewardRequest
from app.application.billing.credits import BillingCreditService
from app.application.rewards.ports import VerifiedRewardCallback
from app.application.runtime_settings import RuntimeSettingsService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.local_recording_models import (
    LocalRecordingSession,
    LocalSlotGrant,
    RewardIntent,
    RewardUserState,
)
from app.infrastructure.db.models import User
from app.settings import AppSettings

CLOUD_MINUTES = "cloud_minutes"
LOCAL_PURPOSES = frozenset({"local_minutes", "local_slot"})
# A device used by more accounts than this is flagged to admins.
SHARED_DEVICE_ACCOUNTS = 3
# reward_intents_per_hour counts intents created in this sliding window.
REWARD_INTENT_WINDOW = timedelta(hours=1)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def cloud_rewards_enabled(settings: AppSettings) -> bool:
    """Rewarded ads stay off until an AdMob ad unit is configured
    (SAVESTREAM_ADMOB_REWARD_AD_UNITS); the API then refuses them cleanly."""
    return settings.reward_provider != "disabled" and bool(settings.admob_reward_ad_units)


def ad_unit_key(value: str | None) -> str:
    """AdMob SSV sends the ad unit's numeric part (``5155016450``); config
    may hold the full id (``ca-app-pub-…/5155016450``)."""
    return (value or "").strip().rsplit("/", 1)[-1]


def seconds_until(moment: datetime, now: datetime) -> int:
    """Whole seconds from ``now`` until ``moment``, rounded up, at least 1."""
    return max(math.ceil((moment - now).total_seconds()), 1)


def reward_day(now: datetime) -> tuple[datetime, datetime]:
    """The UTC day rewarded-ad caps count in (resets at 00:00 UTC)."""
    start = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)
    return start, start + timedelta(days=1)


class RewardService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def create(
        self,
        user_id: uuid.UUID,
        payload: CreateRewardRequest,
    ) -> RewardIntent:
        if self.settings.reward_provider == "disabled":
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Reward verification is disabled",
                status_code=503,
                retryable=True,
            )
        if payload.purpose in LOCAL_PURPOSES and not self.settings.local_recording_enabled:
            raise ApplicationError(
                "REWARD_PURPOSE_RETIRED",
                "On-device recording rewards are no longer available",
                status_code=410,
            )
        now = utcnow()
        state = await self.session.get(RewardUserState, user_id)
        if (
            state is not None
            and state.locked_until is not None
            and aware(state.locked_until) > now
        ):
            raise ApplicationError(
                "REWARD_LOCKED",
                "Reward verification is temporarily locked",
                status_code=429,
                details={
                    "locked_until": aware(state.locked_until).isoformat(),
                    "retry_after_seconds": seconds_until(aware(state.locked_until), now),
                },
            )

        if payload.purpose == CLOUD_MINUTES:
            return await self._create_cloud(user_id, payload, now)

        start, end = reward_day(now)
        valid_today = int(
            await self.session.scalar(
                select(func.count())
                .select_from(RewardIntent)
                .where(
                    RewardIntent.user_id == user_id,
                    RewardIntent.status == "valid",
                    RewardIntent.verified_at >= start,
                    RewardIntent.verified_at < end,
                )
            )
            or 0
        )
        reward_daily_cap = await RuntimeSettingsService(
            self.session, self.settings
        ).integer("reward_daily_cap")
        if valid_today >= reward_daily_cap:
            raise ApplicationError(
                "REWARD_DAILY_CAP_REACHED",
                "Daily rewarded-ad limit reached",
                status_code=409,
                details={"limit": reward_daily_cap},
            )

        session_id: uuid.UUID | None = None
        if payload.session_id is not None:
            try:
                session_id = uuid.UUID(payload.session_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid local recording session id",
                    status_code=400,
                ) from exc
            local_session = await self.session.scalar(
                select(LocalRecordingSession).where(
                    LocalRecordingSession.id == session_id,
                    LocalRecordingSession.user_id == user_id,
                    LocalRecordingSession.status == "active",
                )
            )
            if local_session is None:
                raise ApplicationError(
                    "RESOURCE_NOT_FOUND",
                    "Local recording session not found",
                    status_code=404,
                )

        reward = RewardIntent(
            user_id=user_id,
            purpose=payload.purpose,
            session_id=session_id,
            status="pending",
            expires_at=now + timedelta(seconds=self.settings.reward_valid_seconds),
        )
        self.session.add(reward)
        await self.session.commit()
        await self.session.refresh(reward)
        return reward

    async def _create_cloud(
        self,
        user_id: uuid.UUID,
        payload: CreateRewardRequest,
        now: datetime,
    ) -> RewardIntent:
        if not cloud_rewards_enabled(self.settings):
            raise ApplicationError(
                "REWARDED_ADS_UNAVAILABLE",
                "Rewarded ads are not available right now",
                status_code=409,
                retryable=False,
            )
        user = await self.session.get(User, user_id)
        if user is None or user.email_verified_at is None:
            raise ApplicationError(
                "EMAIL_NOT_VERIFIED",
                "Verify your email to earn minutes from ads",
                status_code=403,
            )
        if not payload.device_id:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "device_id is required for cloud minute rewards",
                status_code=400,
            )
        window_start = now - REWARD_INTENT_WINDOW
        recent_in_window = (
            select(RewardIntent.created_at)
            .where(
                RewardIntent.user_id == user_id,
                RewardIntent.created_at >= window_start,
            )
        )
        recent = int(
            await self.session.scalar(
                select(func.count()).select_from(recent_in_window.subquery())
            )
            or 0
        )
        limit = self.settings.reward_intents_per_hour
        if recent >= limit:
            # Sliding window: a new intent is allowed once enough of the
            # oldest ones in the window have aged out of it.
            frees_slot = await self.session.scalar(
                recent_in_window.order_by(RewardIntent.created_at.asc())
                .offset(recent - limit)
                .limit(1)
            )
            retry_after = (
                seconds_until(aware(frees_slot) + REWARD_INTENT_WINDOW, now)
                if frees_slot is not None
                else int(REWARD_INTENT_WINDOW.total_seconds())
            )
            raise ApplicationError(
                "RATE_LIMITED",
                "Too many rewarded ads started. Try again later.",
                status_code=429,
                retryable=True,
                details={
                    "retry_after_seconds": retry_after,
                    "limit": limit,
                    "window_seconds": int(REWARD_INTENT_WINDOW.total_seconds()),
                },
            )
        await self._check_cloud_caps(user_id, payload.device_id, now)

        reward = RewardIntent(
            user_id=user_id,
            purpose=CLOUD_MINUTES,
            status="pending",
            device_id=payload.device_id,
            expires_at=now + timedelta(seconds=self.settings.reward_cloud_intent_seconds),
        )
        self.session.add(reward)
        await self.session.commit()
        await self.session.refresh(reward)
        return reward

    async def cloud_rewards_today(self, user_id: uuid.UUID, now: datetime | None = None) -> int:
        start, end = reward_day(now or utcnow())
        return int(
            await self.session.scalar(
                select(func.count())
                .select_from(RewardIntent)
                .where(
                    RewardIntent.user_id == user_id,
                    RewardIntent.purpose == CLOUD_MINUTES,
                    RewardIntent.status == "valid",
                    RewardIntent.verified_at >= start,
                    RewardIntent.verified_at < end,
                )
            )
            or 0
        )

    async def _check_cloud_caps(
        self,
        user_id: uuid.UUID,
        device_id: str | None,
        now: datetime,
        *,
        exclude: uuid.UUID | None = None,
    ) -> None:
        """Daily cap per user and per device (UTC day)."""
        start, end = reward_day(now)
        cap = await RuntimeSettingsService(self.session, self.settings).integer(
            "reward_cloud_daily_cap"
        )
        today = select(func.count()).select_from(RewardIntent).where(
            RewardIntent.purpose == CLOUD_MINUTES,
            RewardIntent.status == "valid",
            RewardIntent.verified_at >= start,
            RewardIntent.verified_at < end,
        )
        if exclude is not None:
            today = today.where(RewardIntent.id != exclude)
        user_count = int(
            await self.session.scalar(today.where(RewardIntent.user_id == user_id)) or 0
        )
        if user_count >= cap:
            raise ApplicationError(
                "REWARD_DAILY_CAP_REACHED",
                "Daily rewarded-ad limit reached",
                status_code=409,
                details={"limit": cap, "resets_at": end.isoformat()},
            )
        if device_id:
            device_count = int(
                await self.session.scalar(today.where(RewardIntent.device_id == device_id))
                or 0
            )
            if device_count >= self.settings.reward_cloud_device_daily_cap:
                raise ApplicationError(
                    "REWARD_DAILY_CAP_REACHED",
                    "Daily rewarded-ad limit reached on this device",
                    status_code=409,
                    details={
                        "limit": self.settings.reward_cloud_device_daily_cap,
                        "resets_at": end.isoformat(),
                        "scope": "device",
                    },
                )

    async def get(
        self,
        user_id: uuid.UUID,
        reward_id: str,
    ) -> RewardIntent:
        try:
            parsed = uuid.UUID(reward_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid reward id",
                status_code=400,
            ) from exc
        reward = await self.session.scalar(
            select(RewardIntent).where(
                RewardIntent.id == parsed,
                RewardIntent.user_id == user_id,
            )
        )
        if reward is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Reward not found",
                status_code=404,
            )
        now = utcnow()
        if reward.status == "pending" and aware(reward.expires_at) <= now:
            reward.status = "expired"
            await self.session.commit()
        elif (
            reward.status == "valid"
            and reward.consumed_at is None
            and reward.valid_until is not None
            and aware(reward.valid_until) <= now
        ):
            reward.status = "expired"
            await self.session.commit()
        return reward

    async def apply_callback(
        self,
        callback: VerifiedRewardCallback,
    ) -> RewardIntent:
        reward = await self.session.get(RewardIntent, callback.reward_id)
        if reward is None or reward.user_id != callback.user_id:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Reward callback does not match an intent",
                status_code=400,
            )

        duplicate = await self.session.scalar(
            select(RewardIntent).where(
                RewardIntent.transaction_id == callback.transaction_id,
                RewardIntent.id != reward.id,
            )
        )
        if duplicate is not None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Reward transaction was already used",
                status_code=400,
            )

        now = utcnow()
        state = await self.session.get(RewardUserState, reward.user_id)
        if state is None:
            state = RewardUserState(user_id=reward.user_id)
            self.session.add(state)
            await self.session.flush()

        if reward.purpose == CLOUD_MINUTES:
            return await self._apply_cloud_callback(reward, callback, now)

        if aware(reward.expires_at) <= now and reward.status != "valid":
            reward.status = "expired"
            reward.transaction_id = callback.transaction_id
            reward.verified_at = now
            await self.session.commit()
            return reward

        if not callback.valid:
            if reward.status != "valid":
                reward.status = "invalid"
                reward.transaction_id = callback.transaction_id
                reward.verified_at = now
                state.invalid_streak += 1
                if state.invalid_streak >= self.settings.reward_invalid_lock_threshold:
                    state.locked_until = now + timedelta(
                        seconds=self.settings.reward_lock_seconds
                    )
            await self.session.commit()
            return reward

        if reward.status == "valid" and reward.transaction_id == callback.transaction_id:
            return reward

        start = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)
        end = start + timedelta(days=1)
        valid_today = int(
            await self.session.scalar(
                select(func.count())
                .select_from(RewardIntent)
                .where(
                    RewardIntent.user_id == reward.user_id,
                    RewardIntent.status == "valid",
                    RewardIntent.verified_at >= start,
                    RewardIntent.verified_at < end,
                    RewardIntent.id != reward.id,
                )
            )
            or 0
        )
        reward_daily_cap = await RuntimeSettingsService(
            self.session, self.settings
        ).integer("reward_daily_cap")
        if valid_today >= reward_daily_cap:
            reward.status = "expired"
            reward.transaction_id = callback.transaction_id
            reward.verified_at = now
            await self.session.commit()
            return reward

        reward.status = "valid"
        reward.transaction_id = callback.transaction_id
        reward.verified_at = now
        reward.valid_until = now + timedelta(seconds=self.settings.reward_valid_seconds)
        state.invalid_streak = 0
        state.locked_until = None
        await self.session.flush()

        if reward.purpose == "local_slot":
            await self._activate_second_slot(reward.user_id, now)

        await self.session.commit()
        await self.session.refresh(reward)
        return reward

    async def _apply_cloud_callback(
        self,
        reward: RewardIntent,
        callback: VerifiedRewardCallback,
        now: datetime,
    ) -> RewardIntent:
        if not callback.valid:
            # A forged callback must not burn the user's real intent: leave it
            # untouched (the webhook answers 400 and the attempt is logged).
            return reward
        if reward.status == "valid":
            return reward  # AdMob retry of a callback already credited
        if reward.status != "pending" or aware(reward.expires_at) <= now:
            reward.status = "expired" if reward.status == "pending" else reward.status
            await self.session.commit()
            return reward

        units = self.settings.admob_reward_ad_units
        minutes = await RuntimeSettingsService(self.session, self.settings).integer(
            "reward_cloud_minutes"
        )
        reward.transaction_id = callback.transaction_id
        reward.verified_at = now
        reward.ad_unit = callback.ad_unit
        # The reward amount set in AdMob is ignored: every valid callback from
        # an allowed ad unit adds the configured cloud minutes.
        if ad_unit_key(callback.ad_unit) not in {ad_unit_key(unit) for unit in units}:
            reward.status = "invalid"
            await self.session.commit()
            return reward
        try:
            await self._check_cloud_caps(reward.user_id, reward.device_id, now, exclude=reward.id)
        except ApplicationError:
            reward.status = "expired"
            await self.session.commit()
            return reward

        reward.status = "valid"
        reward.valid_until = now
        reward.consumed_at = now
        reward.credits_granted = minutes
        if minutes > 0:
            await BillingCreditService(self.session).grant_reward(
                user_id=reward.user_id, reward_id=reward.id, credits=minutes
            )
        await self.session.commit()
        await self.session.refresh(reward)
        return reward

    async def _activate_second_slot(
        self,
        user_id: uuid.UUID,
        now: datetime,
    ) -> LocalSlotGrant | None:
        active = await self.session.scalar(
            select(LocalSlotGrant)
            .where(
                LocalSlotGrant.user_id == user_id,
                LocalSlotGrant.expires_at > now,
            )
            .order_by(LocalSlotGrant.expires_at.desc())
            .limit(1)
        )
        if active is not None:
            return active

        rewards = list(
            (
                await self.session.scalars(
                    select(RewardIntent)
                    .where(
                        RewardIntent.user_id == user_id,
                        RewardIntent.purpose == "local_slot",
                        RewardIntent.status == "valid",
                        RewardIntent.consumed_at.is_(None),
                        RewardIntent.valid_until > now,
                    )
                    .order_by(RewardIntent.verified_at)
                    .limit(2)
                )
            ).all()
        )
        if len(rewards) < 2:
            return None

        expires_at = min(
            aware(item.valid_until)
            for item in rewards
            if item.valid_until is not None
        )
        for item in rewards:
            item.consumed_at = now
        grant = LocalSlotGrant(
            user_id=user_id,
            reward_ids=[str(item.id) for item in rewards],
            expires_at=expires_at,
        )
        self.session.add(grant)
        await self.session.flush()
        return grant
