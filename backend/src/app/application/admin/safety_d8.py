from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.admin.recordings_d3 import AdminRecordingService
from app.application.creator_safety import normalize_creator_source
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES, RecordingStatus
from app.domain.watches.state import WatchStatus
from app.infrastructure.db.admin_models import (
    AdminComplaintCase,
    AdminComplaintEvent,
    AdminCreatorBlock,
)
from app.infrastructure.db.models import UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


COMPLAINT_STATUSES = {"new", "reviewing", "resolved", "rejected"}
COMPLAINT_KINDS = {"copyright", "abuse"}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(case: AdminComplaintCase) -> str:
    payload = json.dumps(
        {"created_at": _aware(case.created_at).isoformat(), "id": str(case.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


class AdminSafetyService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def create_complaint(
        self,
        *,
        principal: AuthPrincipal,
        kind: str,
        complainant_name: str,
        complainant_email: str,
        channel_source_type: str | None,
        channel_source_value: str | None,
        recording_id: str | None,
        summary: str,
        body: str,
    ) -> AdminComplaintCase:
        if kind not in COMPLAINT_KINDS:
            raise ApplicationError("VALIDATION_ERROR", "Invalid complaint kind", status_code=400)
        parsed_recording_id: uuid.UUID | None = None
        if recording_id:
            try:
                parsed_recording_id = uuid.UUID(recording_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid recording id", status_code=400
                ) from exc
            recording = await self.session.get(Recording, parsed_recording_id)
            if recording is None:
                raise ApplicationError(
                    "RESOURCE_NOT_FOUND", "Recording not found", status_code=404
                )
            if channel_source_type is None or channel_source_value is None:
                channel_source_type = recording.source_type
                channel_source_value = (
                    recording.resolved_username
                    if recording.resolved_username
                    else recording.source_value
                )

        normalized_value = (
            normalize_creator_source(channel_source_type, channel_source_value)
            if channel_source_type and channel_source_value
            else None
        )
        case = AdminComplaintCase(
            kind=kind,
            complainant_name=complainant_name.strip(),
            complainant_email=complainant_email.strip().casefold(),
            channel_source_type=channel_source_type,
            channel_source_value=normalized_value,
            recording_id=parsed_recording_id,
            summary=summary.strip(),
            body=body.strip(),
            status="new",
            created_by_user_id=principal.user_id,
        )
        self.session.add(case)
        await self.session.flush()
        self.session.add(
            AdminComplaintEvent(
                complaint_id=case.id,
                actor_user_id=principal.user_id,
                action="created",
                note="Complaint case created from an external report.",
                metadata_json={"kind": kind},
            )
        )
        await self.session.flush()
        return case

    async def list_complaints(
        self,
        *,
        limit: int,
        cursor: str | None,
        status: str | None,
        kind: str | None,
        query: str | None,
    ) -> tuple[list[AdminComplaintCase], str | None, bool]:
        statement = select(AdminComplaintCase)
        if status:
            if status not in COMPLAINT_STATUSES:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid complaint status", status_code=400
                )
            statement = statement.where(AdminComplaintCase.status == status)
        if kind:
            if kind not in COMPLAINT_KINDS:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid complaint kind", status_code=400
                )
            statement = statement.where(AdminComplaintCase.kind == kind)
        if query:
            needle = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    AdminComplaintCase.complainant_email.ilike(needle),
                    AdminComplaintCase.summary.ilike(needle),
                    AdminComplaintCase.channel_source_value.ilike(needle),
                )
            )
        if cursor:
            created_at, case_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    AdminComplaintCase.created_at < created_at,
                    and_(
                        AdminComplaintCase.created_at == created_at,
                        AdminComplaintCase.id < case_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        AdminComplaintCase.created_at.desc(),
                        AdminComplaintCase.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        page = rows[:limit]
        return (
            page,
            _encode_cursor(page[-1]) if has_more and page else None,
            has_more,
        )

    async def get_complaint(self, complaint_id: str) -> AdminComplaintCase:
        try:
            parsed = uuid.UUID(complaint_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Complaint not found", status_code=404
            ) from exc
        case = await self.session.get(AdminComplaintCase, parsed)
        if case is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Complaint not found", status_code=404
            )
        return case

    async def complaint_timeline(
        self, complaint_id: uuid.UUID
    ) -> list[AdminComplaintEvent]:
        return list(
            (
                await self.session.scalars(
                    select(AdminComplaintEvent)
                    .where(AdminComplaintEvent.complaint_id == complaint_id)
                    .order_by(AdminComplaintEvent.created_at, AdminComplaintEvent.id)
                )
            ).all()
        )

    async def update_complaint(
        self,
        *,
        complaint_id: str,
        principal: AuthPrincipal,
        status: str,
        assigned_to_user_id: str | None,
        reason: str,
    ) -> tuple[AdminComplaintCase, dict[str, object]]:
        if status not in COMPLAINT_STATUSES:
            raise ApplicationError(
                "VALIDATION_ERROR", "Invalid complaint status", status_code=400
            )
        case = await self.get_complaint(complaint_id)
        before = {
            "status": case.status,
            "assigned_to_user_id": (
                str(case.assigned_to_user_id) if case.assigned_to_user_id else None
            ),
        }
        assigned: uuid.UUID | None = None
        if assigned_to_user_id:
            try:
                assigned = uuid.UUID(assigned_to_user_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid assignee id", status_code=400
                ) from exc
        case.status = status
        case.assigned_to_user_id = assigned
        case.resolved_at = utcnow() if status in {"resolved", "rejected"} else None
        self.session.add(
            AdminComplaintEvent(
                complaint_id=case.id,
                actor_user_id=principal.user_id,
                action="status_updated",
                note=reason,
                metadata_json={
                    "before": before,
                    "after": {
                        "status": case.status,
                        "assigned_to_user_id": (
                            str(assigned) if assigned is not None else None
                        ),
                    },
                },
            )
        )
        await self.session.flush()
        return case, before

    async def _matching_watches(
        self, source_type: str, source_value: str
    ) -> list[Watch]:
        statement = select(Watch).where(Watch.deleted_at.is_(None))
        if source_type == "username":
            statement = statement.where(
                or_(
                    Watch.resolved_username == source_value,
                    and_(
                        Watch.source_type == "username",
                        Watch.source_value == source_value,
                    ),
                )
            )
        elif source_type == "room_id":
            statement = statement.where(
                or_(
                    Watch.resolved_room_id == source_value,
                    and_(
                        Watch.source_type == "room_id",
                        Watch.source_value == source_value,
                    ),
                )
            )
        else:
            statement = statement.where(
                Watch.source_type == source_type,
                Watch.source_value == source_value,
            )
        return list((await self.session.scalars(statement)).all())

    async def _matching_recordings(
        self, source_type: str, source_value: str
    ) -> list[Recording]:
        statement = select(Recording).where(Recording.deleted_at.is_(None))
        if source_type == "username":
            statement = statement.where(
                or_(
                    Recording.resolved_username == source_value,
                    and_(
                        Recording.source_type == "username",
                        Recording.source_value == source_value,
                    ),
                )
            )
        elif source_type == "room_id":
            statement = statement.where(
                or_(
                    Recording.room_id == source_value,
                    and_(
                        Recording.source_type == "room_id",
                        Recording.source_value == source_value,
                    ),
                )
            )
        else:
            statement = statement.where(
                Recording.source_type == source_type,
                Recording.source_value == source_value,
            )
        return list((await self.session.scalars(statement)).all())

    async def _notify_affected_users(
        self,
        *,
        block: AdminCreatorBlock,
        user_ids: set[uuid.UUID],
    ) -> None:
        for user_id in user_ids:
            notification_id = uuid.uuid5(
                uuid.NAMESPACE_URL,
                f"savestream:{user_id}:creator_block:{block.id}",
            )
            if await self.session.get(UserNotification, notification_id) is not None:
                continue
            notification = UserNotification(
                id=notification_id,
                user_id=user_id,
                kind="creator_unavailable",
                title="Channel temporarily unavailable",
                body=(
                    "A channel you follow is temporarily unavailable while "
                    "a safety report is reviewed."
                ),
                resource_type=None,
                resource_id=None,
                dedupe_key=f"creator_block:{block.id}",
            )
            self.session.add(notification)
            await self.session.flush()
            await OutboxWriter().enqueue(
                self.session,
                topic="notification.push",
                aggregate_type="notification",
                aggregate_id=str(notification.id),
                payload={"notification_id": str(notification.id)},
            )

    async def block_creator(
        self,
        *,
        principal: AuthPrincipal,
        source_type: str,
        source_value: str,
        complaint_id: str | None,
        reason: str,
    ) -> tuple[AdminCreatorBlock, list[str], list[str]]:
        normalized = normalize_creator_source(source_type, source_value)
        parsed_complaint: uuid.UUID | None = None
        if complaint_id:
            case = await self.get_complaint(complaint_id)
            parsed_complaint = case.id

        block = await self.session.scalar(
            select(AdminCreatorBlock).where(
                AdminCreatorBlock.source_type == source_type,
                AdminCreatorBlock.source_value == normalized,
            )
        )
        if block is None:
            block = AdminCreatorBlock(
                source_type=source_type,
                source_value=normalized,
                complaint_id=parsed_complaint,
                reason=reason,
                blocked_by_user_id=principal.user_id,
            )
            self.session.add(block)
        elif block.unblocked_at is None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "This creator is already blocked",
                status_code=409,
            )
        else:
            block.complaint_id = parsed_complaint
            block.reason = reason
            block.blocked_by_user_id = principal.user_id
            block.unblocked_at = None
            block.unblocked_by_user_id = None
            block.unblock_reason = None
            block.created_at = utcnow()
        await self.session.flush()

        watches = await self._matching_watches(source_type, normalized)
        paused_watch_ids: list[str] = []
        user_ids: set[uuid.UUID] = set()
        for watch in watches:
            user_ids.add(watch.user_id)
            if watch.status != WatchStatus.DISABLED.value:
                watch.status = WatchStatus.PAUSED.value
                watch.next_check_at = None
                watch.scheduler_lease_id = None
                watch.scheduler_lease_expires_at = None
                watch.last_error = "creator_blocked"
                paused_watch_ids.append(str(watch.id))

        recordings = await self._matching_recordings(source_type, normalized)
        active_values = {status.value for status in ACTIVE_RECORDING_STATUSES}
        active_values.add(RecordingStatus.WAITING_FOR_CLOUD_SLOT.value)
        stopped_recording_ids: list[str] = []
        recording_service = AdminRecordingService(self.session, self.settings)
        for recording in recordings:
            user_ids.add(recording.user_id)
            if recording.status not in active_values:
                continue
            await recording_service.stop_recording(str(recording.id))
            stopped_recording_ids.append(str(recording.id))

        await self._notify_affected_users(block=block, user_ids=user_ids)
        if parsed_complaint is not None:
            self.session.add(
                AdminComplaintEvent(
                    complaint_id=parsed_complaint,
                    actor_user_id=principal.user_id,
                    action="creator_blocked",
                    note=reason,
                    metadata_json={
                        "source_type": source_type,
                        "source_value": normalized,
                        "stopped_recordings": stopped_recording_ids,
                        "paused_watches": paused_watch_ids,
                    },
                )
            )
        await self.session.flush()
        return block, stopped_recording_ids, paused_watch_ids

    async def unblock_creator(
        self,
        *,
        block_id: str,
        principal: AuthPrincipal,
        reason: str,
    ) -> AdminCreatorBlock:
        try:
            parsed = uuid.UUID(block_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Creator block not found", status_code=404
            ) from exc
        block = await self.session.get(AdminCreatorBlock, parsed)
        if block is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Creator block not found", status_code=404
            )
        if block.unblocked_at is not None:
            raise ApplicationError(
                "VALIDATION_ERROR", "Creator block is already inactive", status_code=409
            )
        block.unblocked_at = utcnow()
        block.unblocked_by_user_id = principal.user_id
        block.unblock_reason = reason

        watches = await self._matching_watches(block.source_type, block.source_value)
        for watch in watches:
            if watch.status == WatchStatus.PAUSED.value and watch.last_error == "creator_blocked":
                watch.status = WatchStatus.ACTIVE.value
                watch.next_check_at = utcnow()
                watch.last_error = None

        if block.complaint_id is not None:
            self.session.add(
                AdminComplaintEvent(
                    complaint_id=block.complaint_id,
                    actor_user_id=principal.user_id,
                    action="creator_unblocked",
                    note=reason,
                    metadata_json={
                        "source_type": block.source_type,
                        "source_value": block.source_value,
                    },
                )
            )
        await self.session.flush()
        return block
