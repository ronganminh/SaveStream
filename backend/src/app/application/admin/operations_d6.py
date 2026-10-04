from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from typing import cast

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import PaymentOrder
from app.infrastructure.db.local_recording_models import (
    LocalRecordingSession,
    RewardIntent,
    RewardUserState,
)
from app.infrastructure.db.models import DeviceRegistration, User


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


class AdminV2OperationsService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def store_transactions(self, *, limit: int = 100) -> list[dict[str, object]]:
        rows = (
            await self.session.execute(
                select(PaymentOrder, User.email)
                .join(User, User.id == PaymentOrder.user_id)
                .where(PaymentOrder.provider.in_(("app_store", "google_play")))
                .order_by(PaymentOrder.updated_at.desc(), PaymentOrder.id.desc())
                .limit(limit)
            )
        ).all()
        items: list[dict[str, object]] = []
        for order, email in rows:
            if order.failure_code == "store_finalize_pending":
                verification_status = "pending"
            elif order.failure_code:
                verification_status = "rejected"
            else:
                verification_status = "verified"
            items.append(
                {
                    "id": str(order.id),
                    "user_id": str(order.user_id),
                    "user_email": email,
                    "provider": order.provider,
                    "provider_reference": order.provider_reference,
                    "status": order.status,
                    "verification_status": verification_status,
                    "rejection_reason": order.failure_message,
                    "credits": order.credits,
                    "refunded_credits": order.refunded_credits,
                    "paid_at": order.paid_at,
                    "updated_at": order.updated_at,
                }
            )
        return items

    async def local_metrics(self, *, days: int = 7) -> list[dict[str, object]]:
        start = utcnow() - timedelta(days=max(days - 1, 0))
        sessions = list(
            (
                await self.session.scalars(
                    select(LocalRecordingSession).where(
                        LocalRecordingSession.started_at >= start
                    )
                )
            ).all()
        )
        by_day: dict[date, dict[str, int]] = defaultdict(
            lambda: {
                "sessions": 0,
                "free_minutes_granted": 0,
                "free_minutes_used": 0,
                "auto_closed_sessions": 0,
            }
        )
        for row in sessions:
            day = _aware(row.started_at).date()
            bucket = by_day[day]
            bucket["sessions"] += 1
            bucket["free_minutes_granted"] += (row.free_granted_seconds + 59) // 60
            used_free_seconds = min(row.recorded_seconds, row.free_granted_seconds)
            bucket["free_minutes_used"] += (used_free_seconds + 59) // 60
            if row.finish_payload_hash == "expired-lease":
                bucket["auto_closed_sessions"] += 1
        return [
            {
                "day": day,
                **by_day.get(
                    day,
                    {
                        "sessions": 0,
                        "free_minutes_granted": 0,
                        "free_minutes_used": 0,
                        "auto_closed_sessions": 0,
                    },
                ),
            }
            for day in (
                (utcnow().date() - timedelta(days=offset))
                for offset in range(days - 1, -1, -1)
            )
        ]

    async def local_sessions(
        self,
        user_id: str,
        *,
        limit: int = 100,
    ) -> list[dict[str, object]]:
        try:
            parsed = uuid.UUID(user_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid user id",
                status_code=400,
            ) from exc
        rows = list(
            (
                await self.session.scalars(
                    select(LocalRecordingSession)
                    .where(LocalRecordingSession.user_id == parsed)
                    .order_by(LocalRecordingSession.started_at.desc())
                    .limit(limit)
                )
            ).all()
        )
        return [
            {
                "id": str(row.id),
                "user_id": str(row.user_id),
                "creator_username": row.creator_username,
                "device_id": row.device_id,
                "device_name": row.device_name,
                "status": row.status,
                "granted_seconds": row.granted_seconds,
                "free_granted_seconds": row.free_granted_seconds,
                "recorded_seconds": row.recorded_seconds,
                "started_at": row.started_at,
                "lease_expires_at": row.lease_expires_at,
                "end_reason": row.end_reason,
                "auto_closed": row.finish_payload_hash == "expired-lease",
            }
            for row in rows
        ]

    async def reward_metrics(self, *, days: int = 7) -> dict[str, object]:
        start = utcnow() - timedelta(days=max(days - 1, 0))
        intents = list(
            (
                await self.session.scalars(
                    select(RewardIntent).where(RewardIntent.created_at >= start)
                )
            ).all()
        )
        by_day: dict[date, dict[str, int]] = defaultdict(
            lambda: {"valid": 0, "invalid": 0, "pending": 0, "expired": 0}
        )
        by_user: dict[uuid.UUID, dict[str, int]] = defaultdict(
            lambda: {"valid": 0, "invalid": 0}
        )
        for row in intents:
            day = _aware(row.created_at).date()
            if row.status in by_day[day]:
                by_day[day][row.status] += 1
            if row.status in {"valid", "invalid"}:
                by_user[row.user_id][row.status] += 1

        states = list((await self.session.scalars(select(RewardUserState))).all())
        states_by_user = {row.user_id: row for row in states}
        now = utcnow()
        locked_accounts = sum(
            1
            for row in states
            if row.locked_until is not None and _aware(row.locked_until) > now
        )

        risky_ids = [
            user_id
            for user_id, counts in by_user.items()
            if counts["invalid"] >= 3
            and counts["invalid"] / max(counts["valid"] + counts["invalid"], 1) >= 0.5
        ]
        emails: dict[uuid.UUID, str] = {}
        if risky_ids:
            email_rows = (
                await self.session.execute(
                    select(User.id, User.email).where(User.id.in_(risky_ids))
                )
            ).all()
            emails = {user_id: email for user_id, email in email_rows}

        high_invalid_users: list[dict[str, object]] = []
        for user_id in risky_ids:
            counts = by_user[user_id]
            total = counts["valid"] + counts["invalid"]
            state = states_by_user.get(user_id)
            high_invalid_users.append(
                {
                    "user_id": str(user_id),
                    "user_email": emails.get(user_id, ""),
                    "valid_count": counts["valid"],
                    "invalid_count": counts["invalid"],
                    "invalid_ratio": counts["invalid"] / max(total, 1),
                    "invalid_streak": state.invalid_streak if state is not None else 0,
                    "locked_until": state.locked_until if state is not None else None,
                }
            )
        high_invalid_users.sort(
            key=lambda item: (
                cast(float, item["invalid_ratio"]),
                cast(int, item["invalid_count"]),
            ),
            reverse=True,
        )

        return {
            "days": [
                {
                    "day": day,
                    **by_day.get(
                        day,
                        {"valid": 0, "invalid": 0, "pending": 0, "expired": 0},
                    ),
                }
                for day in (
                    (utcnow().date() - timedelta(days=offset))
                    for offset in range(days - 1, -1, -1)
                )
            ],
            "locked_accounts": locked_accounts,
            "high_invalid_users": high_invalid_users[:100],
        }

    async def unlock_rewards_user(
        self,
        user_id: str,
    ) -> dict[str, object]:
        try:
            parsed = uuid.UUID(user_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid user id",
                status_code=400,
            ) from exc
        row = await self.session.get(RewardUserState, parsed)
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Reward state not found",
                status_code=404,
            )
        previous_locked_until = row.locked_until
        previous_invalid_streak = row.invalid_streak
        row.locked_until = None
        row.invalid_streak = 0
        await self.session.flush()
        return {
            "user_id": str(parsed),
            "unlocked": True,
            "previous_locked_until": previous_locked_until,
            "previous_invalid_streak": previous_invalid_streak,
        }

    async def device_distribution(self) -> list[dict[str, object]]:
        rows = (
            await self.session.execute(
                select(
                    DeviceRegistration.platform,
                    DeviceRegistration.app_version,
                    func.count(DeviceRegistration.id),
                    func.sum(
                        case(
                            (DeviceRegistration.push_token.is_not(None), 1),
                            else_=0,
                        )
                    ),
                )
                .group_by(
                    DeviceRegistration.platform,
                    DeviceRegistration.app_version,
                )
                .order_by(
                    DeviceRegistration.platform,
                    DeviceRegistration.app_version,
                )
            )
        ).all()
        items: list[dict[str, object]] = []
        for platform, app_version, devices, active_push_tokens in rows:
            active = int(active_push_tokens or 0)
            total = int(devices or 0)
            items.append(
                {
                    "platform": platform,
                    "app_version": app_version,
                    "devices": total,
                    "active_push_tokens": active,
                    "removed_push_tokens": max(total - active, 0),
                }
            )
        return items
