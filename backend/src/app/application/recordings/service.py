from __future__ import annotations

import base64
import hashlib
import json
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.credits.service import CreditService
from app.application.notifications.service import ensure_recording_notification
from app.application.quotas.service import QuotaService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import (
    RecordingStatus,
    actions_for_status,
    transition,
)
from app.infrastructure.db.models import IdempotencyKey
from app.infrastructure.db.recording_models import (
    Recording,
    RecordingArtifact,
    RecordingEvent,
)
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def normalize_source(source: Source) -> str:
    value = source.value.strip()
    if source.type == "username":
        value = value.lstrip("@").casefold()
    return value


def dedupe_key(user_id: uuid.UUID, source: Source) -> str:
    normalized = f"{user_id}:{source.type}:{normalize_source(source)}"
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def room_session_key(user_id: uuid.UUID, room_id: str) -> str:
    normalized = f"{user_id}:tiktok-room:{room_id.strip()}"
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def request_hash(payload: CreateRecordingRequest) -> str:
    canonical = json.dumps(
        payload.model_dump(mode="json"),
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def encode_cursor(recording: Recording) -> str:
    payload = json.dumps(
        {"created_at": aware(recording.created_at).isoformat(), "id": str(recording.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


async def append_event(
    session: AsyncSession,
    recording: Recording,
    event_type: str,
) -> RecordingEvent:
    maximum = await session.scalar(
        select(func.max(RecordingEvent.sequence)).where(
            RecordingEvent.recording_id == recording.id
        )
    )
    event = RecordingEvent(
        recording_id=recording.id,
        sequence=int(maximum or 0) + 1,
        event_type=event_type,
        data={
            "status": recording.status,
            "duration_seconds": recording.duration_seconds,
            "bytes_recorded": recording.bytes_recorded,
        },
    )
    session.add(event)
    await session.flush()
    await ensure_recording_notification(session, recording, event_type)
    return event


@dataclass(frozen=True, slots=True)
class RecordingPage:
    items: list[Recording]
    next_cursor: str | None
    has_more: bool


class RecordingService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        *,
        outbox: OutboxWriter | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.outbox = outbox or OutboxWriter()

    async def create(
        self,
        principal: AuthPrincipal,
        payload: CreateRecordingRequest,
        *,
        idempotency_key: str,
    ) -> Recording:
        return await self.create_for_user(
            principal.user_id,
            payload,
            idempotency_key=idempotency_key,
        )

    async def create_for_user(
        self,
        user_id: uuid.UUID,
        payload: CreateRecordingRequest,
        *,
        idempotency_key: str,
    ) -> Recording:
        try:
            uuid.UUID(idempotency_key)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Idempotency-Key must be a UUID",
                status_code=400,
            ) from exc

        if (
            payload.max_duration_seconds is not None
            and payload.max_duration_seconds > self.settings.recording_max_duration_seconds
        ):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "max_duration_seconds exceeds the current hard limit",
                status_code=400,
                details={"max": self.settings.recording_max_duration_seconds},
            )

        namespace = f"recording:create:{user_id}"
        digest = request_hash(payload)
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
            recording_id = (existing_key.response_body or {}).get("recording_id")
            if recording_id:
                try:
                    parsed = uuid.UUID(str(recording_id))
                except ValueError:
                    parsed = None
                if parsed is not None:
                    replay = await self.session.scalar(
                        select(Recording).where(
                            Recording.id == parsed,
                            Recording.user_id == user_id,
                        )
                    )
                    if replay is not None:
                        return replay

        await QuotaService(self.session, self.settings).check_recording_create(user_id)

        source = Source(type=payload.source.type, value=normalize_source(payload.source))
        active_key = dedupe_key(user_id, source)
        active = await self.session.scalar(
            select(Recording).where(
                Recording.active_dedupe_key == active_key,
                Recording.deleted_at.is_(None),
            )
        )
        if active is not None:
            raise ApplicationError(
                "RECORDING_ALREADY_ACTIVE",
                "An active recording already exists for this source",
                status_code=409,
                details={"recording_id": str(active.id)},
            )

        recording = Recording(
            user_id=user_id,
            source_type=source.type,
            source_value=source.value,
            room_session_key=(
                room_session_key(user_id, source.value)
                if source.type == "room_id"
                else None
            ),
            status=RecordingStatus.QUEUED.value,
            active_dedupe_key=active_key,
            max_duration_seconds=payload.max_duration_seconds,
            quality=payload.quality,
            container=payload.container,
            estimated_max_cost=0,
        )
        max_duration = (
            payload.max_duration_seconds
            or self.settings.recording_max_duration_seconds
        )

        try:
            async with self.session.begin_nested():
                self.session.add(recording)
                await self.session.flush()

                reservation, estimated_max_cost = await CreditService(
                    self.session
                ).reserve_recording(
                    user_id=user_id,
                    recording_id=recording.id,
                    max_duration_seconds=max_duration,
                )
                recording.estimated_max_cost = estimated_max_cost
                recording.credit_reservation_id = str(reservation.id)

                await append_event(self.session, recording, "recording.queued")
                await self.outbox.enqueue(
                    self.session,
                    topic="recording.requested",
                    aggregate_type="recording",
                    aggregate_id=str(recording.id),
                    payload={"recording_id": str(recording.id)},
                )
                self.session.add(
                    IdempotencyKey(
                        namespace=namespace,
                        key=idempotency_key,
                        request_hash=digest,
                        response_status=202,
                        response_body={"recording_id": str(recording.id)},
                        expires_at=utcnow()
                        + timedelta(seconds=self.settings.idempotency_ttl_seconds),
                    )
                )
        except IntegrityError as exc:
            raise ApplicationError(
                "RECORDING_ALREADY_ACTIVE",
                "An active recording already exists for this source",
                status_code=409,
            ) from exc

        await self.session.commit()
        await self.session.refresh(recording)
        return recording

    async def get(self, principal: AuthPrincipal, recording_id: str) -> Recording:
        try:
            parsed = uuid.UUID(recording_id)
        except ValueError as exc:
            raise self._not_found() from exc
        recording = await self.session.scalar(
            select(Recording).where(
                Recording.id == parsed,
                Recording.user_id == principal.user_id,
                Recording.deleted_at.is_(None),
            )
        )
        if recording is None:
            raise self._not_found()
        return recording

    async def list(
        self,
        principal: AuthPrincipal,
        *,
        limit: int,
        cursor: str | None,
        status: str | None,
    ) -> RecordingPage:
        statement = select(Recording).where(
            Recording.user_id == principal.user_id,
            Recording.deleted_at.is_(None),
        )
        if status is not None:
            try:
                RecordingStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid recording status", status_code=400
                ) from exc
            statement = statement.where(Recording.status == status)
        if cursor:
            created_at, recording_id = decode_cursor(cursor)
            statement = statement.where(
                or_(
                    Recording.created_at < created_at,
                    and_(
                        Recording.created_at == created_at,
                        Recording.id < recording_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(Recording.created_at.desc(), Recording.id.desc()).limit(
                        limit + 1
                    )
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = encode_cursor(items[-1]) if has_more and items else None
        return RecordingPage(items=items, next_cursor=next_cursor, has_more=has_more)

    async def stop(self, principal: AuthPrincipal, recording_id: str) -> Recording:
        recording = await self.get(principal, recording_id)
        current = RecordingStatus(recording.status)
        if not actions_for_status(current).can_stop:
            raise ApplicationError(
                "RECORDING_NOT_STOPPABLE",
                "Recording cannot be stopped in its current state",
                status_code=409,
            )
        recording.status = transition(current, RecordingStatus.STOP_REQUESTED).value
        await append_event(self.session, recording, "recording.stop_requested")
        await self.session.commit()
        await self.session.refresh(recording)
        return recording

    async def soft_delete(self, principal: AuthPrincipal, recording_id: str) -> None:
        recording = await self.get(principal, recording_id)
        status = RecordingStatus(recording.status)
        if not actions_for_status(status).can_delete:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Recording cannot be deleted in its current state",
                status_code=409,
            )
        now = utcnow()
        recording.deleted_at = now
        recording.cleanup_requested_at = now
        await self.outbox.enqueue(
            self.session,
            topic="recording.cleanup",
            aggregate_type="recording",
            aggregate_id=str(recording.id),
            payload={"recording_id": str(recording.id)},
        )
        await self.session.commit()

    async def artifacts(
        self, principal: AuthPrincipal, recording_id: str
    ) -> Sequence[RecordingArtifact]:
        recording = await self.get(principal, recording_id)
        return list(
            (
                await self.session.scalars(
                    select(RecordingArtifact)
                    .where(
                        RecordingArtifact.recording_id == recording.id,
                        RecordingArtifact.deleted_at.is_(None),
                    )
                    .order_by(RecordingArtifact.created_at)
                )
            ).all()
        )

    async def artifact(
        self, principal: AuthPrincipal, artifact_id: str
    ) -> RecordingArtifact:
        try:
            parsed = uuid.UUID(artifact_id)
        except ValueError as exc:
            raise self._artifact_not_found() from exc
        artifact = await self.session.scalar(
            select(RecordingArtifact)
            .join(Recording, Recording.id == RecordingArtifact.recording_id)
            .where(
                RecordingArtifact.id == parsed,
                RecordingArtifact.deleted_at.is_(None),
                Recording.user_id == principal.user_id,
                Recording.deleted_at.is_(None),
            )
        )
        if artifact is None:
            raise self._artifact_not_found()
        return artifact

    @staticmethod
    def _not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND", "Recording not found", status_code=404
        )

    @staticmethod
    def _artifact_not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND", "Artifact not found", status_code=404
        )


class RecordingStateStore:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def claim(self, recording_id: uuid.UUID) -> tuple[Recording, uuid.UUID] | None:
        recording = await self.session.scalar(
            select(Recording).where(Recording.id == recording_id).with_for_update()
        )
        if recording is None or recording.deleted_at is not None:
            return None

        status = RecordingStatus(recording.status)
        if status is RecordingStatus.STOP_REQUESTED:
            await CreditService(self.session).release_recording(
                recording_id=recording.id,
                reason="stopped_before_start",
            )
            recording.status = RecordingStatus.STOPPED.value
            recording.ended_at = utcnow()
            recording.active_dedupe_key = None
            recording.actual_cost = 0
            await append_event(self.session, recording, "recording.stopped")
            await self.session.commit()
            return None
        if status in {
            RecordingStatus.COMPLETED,
            RecordingStatus.FAILED,
            RecordingStatus.STOPPED,
        }:
            return None

        now = utcnow()
        fresh = (
            recording.heartbeat_at is not None
            and aware(recording.heartbeat_at)
            > now - timedelta(seconds=self.settings.recording_stale_after_seconds)
        )
        if recording.worker_lease_id is not None and fresh:
            return None
        if recording.worker_attempts >= self.settings.recording_max_attempts:
            await self.fail(
                recording,
                code="SERVICE_UNAVAILABLE",
                message="Recording worker retry limit exceeded",
                retryable=False,
            )
            return None

        lease = uuid.uuid4()
        recovered = recording.worker_lease_id is not None
        recording.worker_lease_id = lease
        recording.worker_attempts += 1
        recording.heartbeat_at = now
        recording.status = RecordingStatus.RESOLVING.value
        await append_event(
            self.session,
            recording,
            "recording.recovered" if recovered else "recording.resolving",
        )
        await self.session.commit()
        await self.session.refresh(recording)
        return recording, lease

    async def heartbeat(
        self,
        recording_id: uuid.UUID,
        lease_id: uuid.UUID,
        *,
        bytes_recorded: int | None = None,
        duration_seconds: int | None = None,
        event_type: str | None = None,
    ) -> bool:
        recording = await self.session.scalar(
            select(Recording).where(
                Recording.id == recording_id,
                Recording.worker_lease_id == lease_id,
            )
        )
        if recording is None:
            return False
        recording.heartbeat_at = utcnow()
        if bytes_recorded is not None:
            recording.bytes_recorded = max(recording.bytes_recorded, bytes_recorded)
        if duration_seconds is not None:
            recording.duration_seconds = max(recording.duration_seconds, duration_seconds)
        if event_type:
            await append_event(self.session, recording, event_type)
        await self.session.commit()
        return True

    async def set_status(
        self,
        recording: Recording,
        target: RecordingStatus,
        event_type: str,
    ) -> None:
        recording.status = transition(RecordingStatus(recording.status), target).value
        now = utcnow()
        if target is RecordingStatus.RECORDING and recording.started_at is None:
            recording.started_at = now
        if target in {
            RecordingStatus.COMPLETED,
            RecordingStatus.FAILED,
            RecordingStatus.STOPPED,
        }:
            recording.ended_at = now
            recording.active_dedupe_key = None
            recording.worker_lease_id = None
        await append_event(self.session, recording, event_type)
        await self.session.commit()

    async def fail(
        self,
        recording: Recording,
        *,
        code: str,
        message: str,
        retryable: bool,
    ) -> None:
        await CreditService(self.session).release_recording(
            recording_id=recording.id,
            reason=code,
        )
        recording.status = RecordingStatus.FAILED.value
        recording.error_code = code
        recording.error_message = message[:4000]
        recording.error_retryable = retryable
        recording.actual_cost = 0
        recording.ended_at = utcnow()
        recording.active_dedupe_key = None
        recording.worker_lease_id = None
        await append_event(self.session, recording, "recording.failed")
        await self.session.commit()
