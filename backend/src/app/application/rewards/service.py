from __future__ import annotations

import uuid
from datetime import datetime, time, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.local_recordings import CreateRewardRequest
from app.application.rewards.ports import VerifiedRewardCallback
from app.application.runtime_settings import RuntimeSettingsService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.local_recording_models import (
    LocalRecordingSession,
    LocalSlotGrant,
    RewardIntent,
    RewardUserState,
)
from app.settings import AppSettings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


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
                details={"locked_until": aware(state.locked_until).isoformat()},
            )

        start = datetime.combine(now.date(), time.min, tzinfo=timezone.utc)
        end = start + timedelta(days=1)
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
