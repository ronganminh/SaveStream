from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import math
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Literal, cast

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.local_recordings import (
    CreateLocalRecordingSessionRequest,
    FinishLocalRecordingSessionRequest,
)
from app.api.schemas.recordings import Source
from app.application.entitlements.service import EntitlementService
from app.application.notifications.service import (
    ensure_free_minutes_low_notification,
)
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.local_recording_models import (
    LocalDailyUsage,
    LocalRecordingSession,
    LocalSlotGrant,
    RewardIntent,
)
from app.infrastructure.db.models import DeviceRegistration, IdempotencyKey
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.recording.runtime import build_recording_runtime
from app.settings import AppSettings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _payload_hash(payload: object) -> str:
    if hasattr(payload, "model_dump"):
        value = payload.model_dump(mode="json")
    else:
        value = payload
    raw = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def _encode_cursor(row: LocalRecordingSession) -> str:
    raw = json.dumps(
        {
            "started_at": aware(row.started_at).isoformat(),
            "id": str(row.id),
        },
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(
            base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8")
        )
        return datetime.fromisoformat(payload["started_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


@dataclass(frozen=True, slots=True)
class LocalStreamGrant:
    session_id: uuid.UUID
    granted_seconds: int
    lease_expires_at: datetime
    stream_url: str
    stream_format: Literal["flv", "hls"]
    stream_headers: dict[str, str]


@dataclass(frozen=True, slots=True)
class LocalRecordingPage:
    items: list[LocalRecordingSession]
    next_cursor: str | None
    has_more: bool


class LocalRecordingService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def _usage(
        self,
        user_id: uuid.UUID,
        usage_day: date,
        *,
        lock: bool = False,
    ) -> LocalDailyUsage:
        statement = select(LocalDailyUsage).where(
            LocalDailyUsage.user_id == user_id,
            LocalDailyUsage.usage_day == usage_day,
        )
        if lock:
            statement = statement.with_for_update()
        row = await self.session.scalar(statement)
        if row is None:
            row = LocalDailyUsage(
                user_id=user_id,
                usage_day=usage_day,
                used_minutes=0,
            )
            self.session.add(row)
            await self.session.flush()
        return row

    async def minutes_remaining(
        self,
        user_id: uuid.UUID,
        *,
        now: datetime | None = None,
    ) -> int:
        current = now or utcnow()
        row = await self.session.scalar(
            select(LocalDailyUsage).where(
                LocalDailyUsage.user_id == user_id,
                LocalDailyUsage.usage_day == current.date(),
            )
        )
        used = row.used_minutes if row is not None else 0
        return max(self.settings.free_local_daily_minutes - used, 0)

    async def active_slot_grant(
        self,
        user_id: uuid.UUID,
        *,
        now: datetime | None = None,
    ) -> LocalSlotGrant | None:
        current = now or utcnow()
        return await self.session.scalar(
            select(LocalSlotGrant)
            .where(
                LocalSlotGrant.user_id == user_id,
                LocalSlotGrant.expires_at > current,
            )
            .order_by(LocalSlotGrant.expires_at.desc())
            .limit(1)
        )

    async def start(
        self,
        user_id: uuid.UUID,
        payload: CreateLocalRecordingSessionRequest,
        *,
        idempotency_key: str,
    ) -> LocalStreamGrant:
        try:
            uuid.UUID(idempotency_key)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Idempotency-Key must be a UUID",
                status_code=400,
            ) from exc

        namespace = f"local-recording:start:{user_id}"
        digest = _payload_hash(payload)
        existing_key = await self.session.scalar(
            select(IdempotencyKey).where(
                IdempotencyKey.namespace == namespace,
                IdempotencyKey.key == idempotency_key,
            )
        )
        if existing_key is not None:
            if existing_key.request_hash != digest:
                raise ApplicationError(
                    "IDEMPOTENCY_KEY_REUSED",
                    "Idempotency key was already used with a different request",
                    status_code=409,
                )
            body = existing_key.response_body or {}
            try:
                return LocalStreamGrant(
                    session_id=uuid.UUID(str(body["session_id"])),
                    granted_seconds=int(body["granted_seconds"]),
                    lease_expires_at=datetime.fromisoformat(body["lease_expires_at"]),
                    stream_url=str(body["stream_url"]),
                    stream_format=cast(
                        Literal["flv", "hls"],
                        str(body["stream_format"]),
                    ),
                    stream_headers=dict(body.get("stream_headers") or {}),
                )
            except (KeyError, ValueError, TypeError) as exc:
                raise ApplicationError(
                    "INTERNAL_ERROR",
                    "Stored local recording idempotency response is invalid",
                    status_code=500,
                ) from exc

        entitlement = await EntitlementService(self.session, self.settings).get(user_id)
        if not entitlement.local.enabled:
            raise ApplicationError(
                "LOCAL_RECORDING_DISABLED",
                "Local recording is disabled for this account",
                status_code=403,
            )

        try:
            watch_id = uuid.UUID(payload.watch_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid watch id",
                status_code=400,
            ) from exc
        watch = await self.session.scalar(
            select(Watch).where(
                Watch.id == watch_id,
                Watch.user_id == user_id,
                Watch.deleted_at.is_(None),
            )
        )
        if watch is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Watch not found",
                status_code=404,
            )

        now = utcnow()
        active = list(
            (
                await self.session.scalars(
                    select(LocalRecordingSession).where(
                        LocalRecordingSession.user_id == user_id,
                        LocalRecordingSession.status == "active",
                    )
                )
            ).all()
        )
        slot_grant = await self.active_slot_grant(user_id, now=now)
        if len(active) >= 2 or (len(active) >= 1 and slot_grant is None):
            raise ApplicationError(
                "LOCAL_SLOT_BUSY",
                "No local recording slot is available",
                status_code=409,
            )

        source = Source.model_validate(
            {"type": watch.source_type, "value": watch.source_value}
        )
        runtime = build_recording_runtime(self.settings)
        try:
            resolved, live = await asyncio.to_thread(
                runtime.resolver.live_status,
                source,
            )
            if not live:
                raise ApplicationError(
                    "CREATOR_NOT_LIVE",
                    "Creator is not LIVE",
                    status_code=409,
                )
            stream_url = await asyncio.to_thread(
                runtime.gateway.get_live_url,
                resolved.room_id,
            )
        except ApplicationError:
            raise
        except Exception as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Unable to resolve local recording stream",
                status_code=503,
                retryable=True,
            ) from exc
        if not stream_url:
            raise ApplicationError(
                "CREATOR_NOT_LIVE",
                "Creator is not LIVE",
                status_code=409,
            )

        device = await self.session.scalar(
            select(DeviceRegistration).where(
                DeviceRegistration.user_id == user_id,
                DeviceRegistration.device_id == payload.device_id,
            )
        )
        device_name = device.device_name if device is not None else payload.device_id

        unlimited = entitlement.local.unlimited
        free_granted_seconds = 0
        if unlimited:
            granted_seconds = self.settings.local_unlimited_lease_seconds
        elif payload.reward_id is not None:
            reward = await self._consume_minutes_reward(
                user_id,
                payload.reward_id,
                now=now,
                session_id=None,
            )
            granted_seconds = self.settings.reward_minutes * 60
            reward.session_id = None
        else:
            remaining = await self.minutes_remaining(user_id, now=now)
            if remaining <= 0:
                raise ApplicationError(
                    "FREE_MINUTES_EXHAUSTED",
                    "Free local recording minutes are exhausted",
                    status_code=402,
                )
            granted_seconds = remaining * 60
            free_granted_seconds = granted_seconds

        lease_expires_at = now + timedelta(seconds=granted_seconds)
        used_slot_grant_id: uuid.UUID | None = None
        if len(active) == 1 and slot_grant is not None:
            lease_expires_at = min(lease_expires_at, aware(slot_grant.expires_at))
            granted_seconds = max(
                1,
                int((lease_expires_at - now).total_seconds()),
            )
            free_granted_seconds = min(free_granted_seconds, granted_seconds)
            used_slot_grant_id = slot_grant.id

        row = LocalRecordingSession(
            user_id=user_id,
            watch_id=watch.id,
            device_id=payload.device_id,
            device_name=device_name,
            creator_username=resolved.username,
            status="active",
            granted_seconds=granted_seconds,
            free_granted_seconds=free_granted_seconds,
            unlimited=unlimited,
            lease_expires_at=lease_expires_at,
            slot_grant_id=used_slot_grant_id,
        )
        self.session.add(row)
        await self.session.flush()

        stream_format: Literal["flv", "hls"] = (
            "hls" if ".m3u8" in stream_url.lower() else "flv"
        )
        response_body = {
            "session_id": str(row.id),
            "granted_seconds": granted_seconds,
            "lease_expires_at": aware(lease_expires_at).isoformat(),
            "stream_url": stream_url,
            "stream_format": stream_format,
            "stream_headers": {},
        }
        self.session.add(
            IdempotencyKey(
                namespace=namespace,
                key=idempotency_key,
                request_hash=digest,
                response_status=201,
                response_body=response_body,
                expires_at=now
                + timedelta(seconds=self.settings.idempotency_ttl_seconds),
            )
        )
        await self.session.commit()
        return LocalStreamGrant(
            session_id=row.id,
            granted_seconds=granted_seconds,
            lease_expires_at=lease_expires_at,
            stream_url=stream_url,
            stream_format=stream_format,
            stream_headers={},
        )

    async def _consume_minutes_reward(
        self,
        user_id: uuid.UUID,
        reward_id: str,
        *,
        now: datetime,
        session_id: uuid.UUID | None,
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
            select(RewardIntent)
            .where(
                RewardIntent.id == parsed,
                RewardIntent.user_id == user_id,
                RewardIntent.purpose == "local_minutes",
                RewardIntent.status == "valid",
                RewardIntent.consumed_at.is_(None),
                RewardIntent.valid_until > now,
                or_(
                    RewardIntent.session_id.is_(None),
                    RewardIntent.session_id == session_id,
                ),
            )
            .with_for_update()
        )
        if reward is None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Reward is not valid for local minutes",
                status_code=400,
            )
        reward.consumed_at = now
        return reward

    async def extend(
        self,
        user_id: uuid.UUID,
        session_id: str,
        *,
        reward_id: str | None,
    ) -> None:
        row = await self._active_session(user_id, session_id, lock=True)
        if row.extension_count >= self.settings.reward_extensions_cap:
            raise ApplicationError(
                "EXTENSION_LIMIT_REACHED",
                "Local recording extension limit reached",
                status_code=409,
            )
        now = utcnow()
        if row.unlimited:
            if self.settings.pro_local_recording != "unlimited":
                raise ApplicationError(
                    "LOCAL_RECORDING_DISABLED",
                    "Local recording is disabled for Pro accounts",
                    status_code=403,
                )
            extra = self.settings.local_unlimited_lease_seconds
        else:
            if reward_id is None:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "reward_id is required for this local recording",
                    status_code=400,
                )
            reward = await self._consume_minutes_reward(
                user_id,
                reward_id,
                now=now,
                session_id=row.id,
            )
            reward.session_id = row.id
            extra = self.settings.reward_minutes * 60

        old_expiry = max(aware(row.lease_expires_at), now)
        new_expiry = old_expiry + timedelta(seconds=extra)
        if row.slot_grant_id is not None:
            grant = await self.session.get(LocalSlotGrant, row.slot_grant_id)
            if grant is not None:
                new_expiry = min(new_expiry, aware(grant.expires_at))
        added_seconds = max(0, int((new_expiry - old_expiry).total_seconds()))
        if added_seconds <= 0:
            raise ApplicationError(
                "LOCAL_SLOT_BUSY",
                "The rewarded second local slot has expired",
                status_code=409,
            )
        row.granted_seconds += added_seconds
        row.extension_count += 1
        row.lease_expires_at = new_expiry
        await self.session.commit()

    async def finish(
        self,
        user_id: uuid.UUID,
        session_id: str,
        payload: FinishLocalRecordingSessionRequest,
    ) -> None:
        try:
            parsed = uuid.UUID(session_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid local recording session id",
                status_code=400,
            ) from exc
        row = await self.session.scalar(
            select(LocalRecordingSession)
            .where(
                LocalRecordingSession.id == parsed,
                LocalRecordingSession.user_id == user_id,
            )
            .with_for_update()
        )
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Local recording session not found",
                status_code=404,
            )
        digest = _payload_hash(payload)
        if row.status != "active":
            if row.finish_payload_hash == digest:
                return
            raise ApplicationError(
                "SESSION_ALREADY_FINISHED",
                "Local recording session is already finished",
                status_code=409,
            )

        charged_seconds = min(payload.recorded_seconds, row.granted_seconds)
        free_seconds = min(charged_seconds, row.free_granted_seconds)
        if free_seconds > 0:
            usage_day = aware(row.started_at).date()
            usage = await self._usage(user_id, usage_day, lock=True)
            usage.used_minutes += math.ceil(free_seconds / 60)
            remaining = max(
                self.settings.free_local_daily_minutes - usage.used_minutes,
                0,
            )
            await ensure_free_minutes_low_notification(
                self.session,
                user_id=user_id,
                usage_day=usage_day,
                minutes_remaining=remaining,
                threshold=self.settings.free_minutes_low_threshold,
            )

        row.recorded_seconds = charged_seconds
        row.size_bytes = payload.size_bytes
        row.end_reason = payload.end_reason
        row.status = payload.status
        row.finish_payload_hash = digest
        await self.session.commit()

    async def close_expired(
        self,
        *,
        now: datetime | None = None,
    ) -> int:
        current = now or utcnow()
        cutoff = current - timedelta(seconds=self.settings.local_lease_grace_seconds)
        rows = list(
            (
                await self.session.scalars(
                    select(LocalRecordingSession)
                    .where(
                        LocalRecordingSession.status == "active",
                        LocalRecordingSession.lease_expires_at <= cutoff,
                    )
                    .with_for_update()
                )
            ).all()
        )
        for row in rows:
            if row.free_granted_seconds > 0:
                usage_day = aware(row.started_at).date()
                usage = await self._usage(row.user_id, usage_day, lock=True)
                usage.used_minutes += math.ceil(row.free_granted_seconds / 60)
                remaining = max(
                    self.settings.free_local_daily_minutes - usage.used_minutes,
                    0,
                )
                await ensure_free_minutes_low_notification(
                    self.session,
                    user_id=row.user_id,
                    usage_day=usage_day,
                    minutes_remaining=remaining,
                    threshold=self.settings.free_minutes_low_threshold,
                )
            row.recorded_seconds = row.granted_seconds
            row.end_reason = "interrupted"
            row.status = "partial"
            row.finish_payload_hash = "expired-lease"
        await self.session.commit()
        return len(rows)

    async def _active_session(
        self,
        user_id: uuid.UUID,
        session_id: str,
        *,
        lock: bool,
    ) -> LocalRecordingSession:
        try:
            parsed = uuid.UUID(session_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid local recording session id",
                status_code=400,
            ) from exc
        statement = select(LocalRecordingSession).where(
            LocalRecordingSession.id == parsed,
            LocalRecordingSession.user_id == user_id,
            LocalRecordingSession.status == "active",
        )
        if lock:
            statement = statement.with_for_update()
        row = await self.session.scalar(statement)
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Active local recording session not found",
                status_code=404,
            )
        return row

    async def list(
        self,
        user_id: uuid.UUID,
        *,
        limit: int,
        cursor: str | None,
    ) -> LocalRecordingPage:
        statement = select(LocalRecordingSession).where(
            LocalRecordingSession.user_id == user_id,
            LocalRecordingSession.deleted_at.is_(None),
            LocalRecordingSession.status.in_(
                ["completed", "partial", "recovered", "failed"]
            ),
        )
        if cursor:
            started_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    LocalRecordingSession.started_at < started_at,
                    and_(
                        LocalRecordingSession.started_at == started_at,
                        LocalRecordingSession.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        LocalRecordingSession.started_at.desc(),
                        LocalRecordingSession.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return LocalRecordingPage(
            items=items,
            next_cursor=_encode_cursor(items[-1]) if has_more and items else None,
            has_more=has_more,
        )

    async def delete(
        self,
        user_id: uuid.UUID,
        recording_id: str,
        *,
        device_id: str,
    ) -> None:
        try:
            parsed = uuid.UUID(recording_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid local recording id",
                status_code=400,
            ) from exc
        row = await self.session.scalar(
            select(LocalRecordingSession).where(
                LocalRecordingSession.id == parsed,
                LocalRecordingSession.user_id == user_id,
                LocalRecordingSession.deleted_at.is_(None),
            )
        )
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Local recording not found",
                status_code=404,
            )
        if row.device_id != device_id:
            raise ApplicationError(
                "NOT_SOURCE_DEVICE",
                "Only the source device can delete local recording metadata",
                status_code=403,
            )
        row.deleted_at = utcnow()
        await self.session.commit()
