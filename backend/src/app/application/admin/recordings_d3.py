from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, case, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.identity.service import utcnow
from app.application.recordings.service import RecordingService, append_event
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import (
    RecordingStatus,
    TERMINAL_RECORDING_STATUSES,
    actions_for_status,
    transition,
)
from app.infrastructure.db.admin_models import AdminWatchCheckMetric
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


GLOBAL_RECORDING_STREAM_LIMIT = 6


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(recording: Recording, sort_order: str) -> str:
    payload = json.dumps(
        {
            "created_at": _aware(recording.created_at).isoformat(),
            "id": str(recording.id),
            "sort_order": sort_order,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(value: str, sort_order: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        if payload.get("sort_order") != sort_order:
            raise ValueError("cursor sort mismatch")
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


class AdminRecordingService:
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

    async def list_recordings(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None,
        channel: str | None,
        status: str | None,
        created_from: datetime | None,
        created_to: datetime | None,
        sort_order: str,
    ) -> tuple[list[Recording], str | None, bool]:
        if sort_order not in {"asc", "desc"}:
            raise ApplicationError("VALIDATION_ERROR", "Invalid sort order", status_code=400)

        statement = select(Recording).where(Recording.deleted_at.is_(None))
        if user_id is not None:
            statement = statement.where(Recording.user_id == user_id)
        if channel:
            needle = f"%{channel.strip()}%"
            statement = statement.where(
                or_(
                    Recording.source_value.ilike(needle),
                    Recording.resolved_username.ilike(needle),
                )
            )
        if status is not None:
            try:
                RecordingStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid recording status",
                    status_code=400,
                ) from exc
            statement = statement.where(Recording.status == status)
        if created_from is not None:
            statement = statement.where(Recording.created_at >= created_from)
        if created_to is not None:
            statement = statement.where(Recording.created_at <= created_to)

        if cursor:
            created_at, row_id = _decode_cursor(cursor, sort_order)
            if sort_order == "desc":
                statement = statement.where(
                    or_(
                        Recording.created_at < created_at,
                        and_(Recording.created_at == created_at, Recording.id < row_id),
                    )
                )
            else:
                statement = statement.where(
                    or_(
                        Recording.created_at > created_at,
                        and_(Recording.created_at == created_at, Recording.id > row_id),
                    )
                )

        order = (
            (Recording.created_at.desc(), Recording.id.desc())
            if sort_order == "desc"
            else (Recording.created_at.asc(), Recording.id.asc())
        )
        rows = list((await self.session.scalars(statement.order_by(*order).limit(limit + 1))).all())
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = (
            _encode_cursor(items[-1], sort_order)
            if has_more and items
            else None
        )
        return items, next_cursor, has_more

    async def get_recording(self, recording_id: str) -> Recording:
        try:
            parsed = uuid.UUID(recording_id)
        except ValueError as exc:
            raise self._not_found() from exc
        recording = await self.session.scalar(
            select(Recording).where(
                Recording.id == parsed,
                Recording.deleted_at.is_(None),
            )
        )
        if recording is None:
            raise self._not_found()
        return recording

    async def retention_days_for_user(self, user_id: uuid.UUID) -> int:
        return await RecordingService(self.session, self.settings).retention_days_for(user_id)

    async def queue_positions(self, recordings: list[Recording]) -> dict[uuid.UUID, int]:
        return await RecordingService(self.session, self.settings).queue_positions(recordings)

    async def playback_artifact(self, recording_id: str) -> RecordingArtifact:
        recording = await self.get_recording(recording_id)
        artifact = await self.session.scalar(
            select(RecordingArtifact)
            .where(
                RecordingArtifact.recording_id == recording.id,
                RecordingArtifact.deleted_at.is_(None),
                RecordingArtifact.kind == "video",
            )
            .order_by(RecordingArtifact.created_at.desc())
            .limit(1)
        )
        if artifact is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Recording video artifact not found",
                status_code=404,
            )
        return artifact

    async def list_waiting_queue(
        self,
        *,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[tuple[Recording, str]], str | None, bool]:
        statement = (
            select(Recording, User.email)
            .join(User, User.id == Recording.user_id)
            .where(
                Recording.deleted_at.is_(None),
                Recording.status == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
            )
        )
        if cursor:
            created_at, row_id = _decode_cursor(cursor, "asc")
            statement = statement.where(
                or_(
                    Recording.created_at > created_at,
                    and_(Recording.created_at == created_at, Recording.id > row_id),
                )
            )
        rows = list(
            (
                await self.session.execute(
                    statement.order_by(Recording.created_at.asc(), Recording.id.asc()).limit(
                        limit + 1
                    )
                )
            ).all()
        )
        has_more = len(rows) > limit
        page = rows[:limit]
        next_cursor = (
            _encode_cursor(page[-1][0], "asc")
            if has_more and page
            else None
        )
        return [(row[0], row[1]) for row in page], next_cursor, has_more

    async def missed_today_count(self) -> int:
        now = utcnow()
        start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
        return int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.status == RecordingStatus.MISSED_NO_CLOUD_SLOT.value,
                    Recording.ended_at >= start,
                )
            )
            or 0
        )

    async def list_watch_channels(
        self,
        *,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        channel = func.coalesce(Watch.resolved_username, Watch.source_value).label("channel")
        statement = (
            select(
                Watch.source_type.label("source_type"),
                channel,
                func.count(Watch.id).label("followers"),
                func.sum(case((Watch.auto_record.is_(True), 1), else_=0)).label(
                    "auto_record_count"
                ),
                func.sum(
                    case(
                        (
                            Watch.status.in_(
                                (
                                    "paused",
                                    "paused_insufficient_credit",
                                    "paused_error",
                                )
                            ),
                            1,
                        ),
                        else_=0,
                    )
                ).label("paused_count"),
                func.sum(case((Watch.failure_count > 0, 1), else_=0)).label(
                    "failing_count"
                ),
                func.max(Watch.failure_count).label("max_failure_count"),
                func.max(Watch.last_checked_at).label("last_checked_at"),
                func.max(Watch.last_error).label("last_error"),
            )
            .where(Watch.deleted_at.is_(None))
            .group_by(Watch.source_type, channel)
        )

        if cursor:
            try:
                padded = cursor + "=" * (-len(cursor) % 4)
                payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
                cursor_type = str(payload["source_type"])
                cursor_channel = str(payload["channel"])
            except (ValueError, KeyError, json.JSONDecodeError) as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR",
                    "Invalid pagination cursor",
                    status_code=400,
                ) from exc
            statement = statement.having(
                or_(
                    Watch.source_type > cursor_type,
                    and_(Watch.source_type == cursor_type, channel > cursor_channel),
                )
            )

        rows = list(
            (
                await self.session.execute(
                    statement.order_by(Watch.source_type.asc(), channel.asc()).limit(limit + 1)
                )
            ).mappings().all()
        )
        has_more = len(rows) > limit
        page = rows[:limit]
        items = [dict(row) for row in page]
        next_cursor = None
        if has_more and page:
            last = page[-1]
            payload = json.dumps(
                {
                    "source_type": str(last["source_type"]),
                    "channel": str(last["channel"]),
                },
                separators=(",", ":"),
            ).encode("utf-8")
            next_cursor = base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")
        return items, next_cursor, has_more

    async def detector_metrics(self) -> dict[str, object]:
        now = utcnow()
        start = now - timedelta(hours=24)
        rows = list(
            (
                await self.session.scalars(
                    select(AdminWatchCheckMetric)
                    .where(AdminWatchCheckMetric.checked_at >= start)
                    .order_by(AdminWatchCheckMetric.checked_at.asc())
                )
            ).all()
        )
        latest_metric = rows[-1] if rows else None
        latest_watch_check = await self.session.scalar(select(func.max(Watch.last_checked_at)))
        last_run_at = latest_metric.checked_at if latest_metric is not None else latest_watch_check

        one_hour = now - timedelta(hours=1)
        recent = [row for row in rows if _aware(row.checked_at) >= one_hour]
        average_latency_ms_1h = (
            round(sum(row.latency_ms for row in recent) / len(recent))
            if recent
            else None
        )
        failure_rate_1h = (
            sum(1 for row in recent if not row.success) / len(recent)
            if recent
            else None
        )

        hour_start = now.replace(minute=0, second=0, microsecond=0) - timedelta(hours=23)
        hourly: list[dict[str, object]] = []
        for index in range(24):
            bucket_start = hour_start + timedelta(hours=index)
            bucket_end = bucket_start + timedelta(hours=1)
            bucket = [
                row
                for row in rows
                if bucket_start <= _aware(row.checked_at) < bucket_end
            ]
            checks = len(bucket)
            failures = sum(1 for row in bucket if not row.success)
            hourly.append(
                {
                    "hour": bucket_start,
                    "checks": checks,
                    "failures": failures,
                    "failure_rate": failures / checks if checks else None,
                    "average_latency_ms": (
                        round(sum(row.latency_ms for row in bucket) / checks)
                        if checks
                        else None
                    ),
                }
            )

        return {
            "last_run_at": last_run_at,
            "last_latency_ms": latest_metric.latency_ms if latest_metric is not None else None,
            "average_latency_ms_1h": average_latency_ms_1h,
            "failure_rate_1h": failure_rate_1h,
            "hourly": hourly,
        }

    async def capacity_metrics(self) -> dict[str, object]:
        now = utcnow()
        history_start = (
            now.replace(minute=0, second=0, microsecond=0)
            - timedelta(hours=(7 * 24) - 1)
        )
        current_in_use = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.status == RecordingStatus.RECORDING.value,
                )
            )
            or 0
        )
        rows = list(
            (
                await self.session.execute(
                    select(Recording.started_at, Recording.ended_at).where(
                        Recording.started_at.is_not(None),
                        or_(
                            Recording.ended_at.is_(None),
                            Recording.ended_at >= history_start,
                        ),
                    )
                )
            ).all()
        )
        intervals: list[tuple[datetime, datetime]] = []
        for started_at, ended_at in rows:
            if started_at is None:
                continue
            normalized_start = _aware(started_at)
            normalized_end = _aware(ended_at) if ended_at is not None else now
            if normalized_start >= now or normalized_end < history_start:
                continue
            intervals.append((normalized_start, normalized_end))

        hourly: list[dict[str, object]] = []
        for index in range(7 * 24):
            bucket_start = history_start + timedelta(hours=index)
            bucket_end = bucket_start + timedelta(hours=1)
            events: list[tuple[datetime, int]] = []
            for started_at, ended_at in intervals:
                if started_at >= bucket_end or ended_at <= bucket_start:
                    continue
                events.append((max(started_at, bucket_start), 1))
                events.append((min(ended_at, bucket_end), -1))
            active = 0
            peak = 0
            for _, delta in sorted(events, key=lambda item: (item[0], item[1])):
                active += delta
                peak = max(peak, active)
            hourly.append(
                {
                    "hour": bucket_start,
                    "max_concurrent": peak,
                    "limit": GLOBAL_RECORDING_STREAM_LIMIT,
                }
            )

        return {
            "current_in_use": current_in_use,
            "global_limit": GLOBAL_RECORDING_STREAM_LIMIT,
            "hourly": hourly,
        }

    async def stop_recording(self, recording_id: str) -> tuple[Recording, RecordingStatus]:
        recording = await self.get_recording(recording_id)
        current = RecordingStatus(recording.status)
        if current is RecordingStatus.WAITING_FOR_CLOUD_SLOT:
            recording.status = RecordingStatus.STOPPED.value
            recording.ended_at = utcnow()
            recording.actual_cost = 0
            recording.active_dedupe_key = None
            await append_event(self.session, recording, "recording.stopped")
        else:
            if not actions_for_status(current).can_stop:
                raise ApplicationError(
                    "RECORDING_NOT_STOPPABLE",
                    "Recording cannot be stopped in its current state",
                    status_code=409,
                )
            recording.status = transition(current, RecordingStatus.STOP_REQUESTED).value
            await append_event(self.session, recording, "recording.stop_requested")
        await self.session.flush()
        return recording, current

    async def delete_recording(self, recording_id: str) -> Recording:
        recording = await self.get_recording(recording_id)
        if not actions_for_status(RecordingStatus(recording.status)).can_delete:
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
        await self.session.flush()
        return recording

    async def extend_retention(
        self,
        recording_id: str,
        *,
        expires_at: datetime,
    ) -> tuple[Recording, datetime | None]:
        recording = await self.get_recording(recording_id)
        if RecordingStatus(recording.status) not in TERMINAL_RECORDING_STATUSES:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Retention can only be changed for a finished recording",
                status_code=409,
            )
        new_expiry = _aware(expires_at)
        if new_expiry <= utcnow():
            raise ApplicationError(
                "VALIDATION_ERROR",
                "expires_at must be in the future",
                status_code=400,
            )
        previous = recording.retention_expires_at
        recording.retention_expires_at = new_expiry
        await self.session.flush()
        return recording, previous

    async def wake_next(self, user_id: uuid.UUID) -> None:
        from app.application.recordings.cloud_slots import CloudSlotQueueService

        await CloudSlotQueueService(
            self.session,
            self.settings,
            outbox=self.outbox,
        ).wake_next(user_id)

    @staticmethod
    def _not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND",
            "Recording not found",
            status_code=404,
        )
