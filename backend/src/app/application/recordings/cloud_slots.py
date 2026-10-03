from __future__ import annotations

import uuid

from sqlalchemy import and_, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.credits.service import CreditService
from app.application.entitlements.service import EntitlementService
from app.application.recordings.service import (
    append_event,
    dedupe_key,
    room_session_key,
    utcnow,
)
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES, RecordingStatus
from app.domain.watches.state import WatchStatus
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


class CloudSlotQueueService:
    """Persistent per-user FIFO queue for Pro automatic cloud recordings.

    waiting_for_cloud_slot is deliberately excluded from ACTIVE_RECORDING_STATUSES,
    so queued waiters never consume one of the user's three cloud slots.
    """

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

    async def queue_for_watch(self, watch: Watch, room_id: str) -> Recording:
        source = Source(type="room_id", value=room_id)
        active_key = dedupe_key(watch.user_id, source)
        existing = await self.session.scalar(
            select(Recording).where(
                Recording.active_dedupe_key == active_key,
                Recording.deleted_at.is_(None),
            )
        )
        if existing is not None:
            return existing

        recording = Recording(
            user_id=watch.user_id,
            source_type="room_id",
            source_value=room_id,
            resolved_username=watch.resolved_username,
            room_id=room_id,
            room_session_key=room_session_key(watch.user_id, room_id),
            status=RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
            active_dedupe_key=active_key,
            max_duration_seconds=None,
            quality="best",
            container="mp4",
            estimated_max_cost=0,
            actual_cost=None,
        )
        try:
            async with self.session.begin_nested():
                self.session.add(recording)
                await self.session.flush()
                await append_event(
                    self.session,
                    recording,
                    "recording.waiting_for_cloud_slot",
                )
        except IntegrityError:
            existing = await self.session.scalar(
                select(Recording).where(
                    Recording.room_session_key
                    == room_session_key(watch.user_id, room_id)
                )
            )
            if existing is not None:
                return existing
            raise
        await self.session.commit()
        await self.session.refresh(recording)
        return recording

    async def queue_position(self, recording: Recording) -> int | None:
        if recording.status != RecordingStatus.WAITING_FOR_CLOUD_SLOT.value:
            return None
        earlier = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.user_id == recording.user_id,
                    Recording.deleted_at.is_(None),
                    Recording.status
                    == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
                    or_(
                        Recording.created_at < recording.created_at,
                        and_(
                            Recording.created_at == recording.created_at,
                            Recording.id < recording.id,
                        ),
                    ),
                )
            )
            or 0
        )
        return earlier + 1

    async def queue_positions(
        self,
        recordings: list[Recording],
    ) -> dict[uuid.UUID, int]:
        waiting = [
            item
            for item in recordings
            if item.status == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value
        ]
        if not waiting:
            return {}
        user_ids = {item.user_id for item in waiting}
        rows = list(
            (
                await self.session.scalars(
                    select(Recording)
                    .where(
                        Recording.user_id.in_(user_ids),
                        Recording.deleted_at.is_(None),
                        Recording.status
                        == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
                    )
                    .order_by(
                        Recording.user_id,
                        Recording.created_at,
                        Recording.id,
                    )
                )
            ).all()
        )
        counters: dict[uuid.UUID, int] = {}
        positions: dict[uuid.UUID, int] = {}
        for row in rows:
            counters[row.user_id] = counters.get(row.user_id, 0) + 1
            positions[row.id] = counters[row.user_id]
        return positions

    async def mark_missed_for_room(
        self,
        *,
        user_id: uuid.UUID,
        room_id: str,
    ) -> int:
        if not room_id:
            return 0
        rows = list(
            (
                await self.session.scalars(
                    select(Recording)
                    .where(
                        Recording.user_id == user_id,
                        Recording.deleted_at.is_(None),
                        Recording.status
                        == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
                        Recording.source_type == "room_id",
                        Recording.source_value == room_id,
                    )
                    .with_for_update()
                )
            ).all()
        )
        for recording in rows:
            recording.status = RecordingStatus.MISSED_NO_CLOUD_SLOT.value
            recording.ended_at = utcnow()
            recording.actual_cost = 0
            recording.active_dedupe_key = None
            recording.worker_lease_id = None
            await append_event(
                self.session,
                recording,
                "recording.missed_no_cloud_slot",
            )
        if rows:
            await self.session.commit()
            await self.wake_next(user_id)
        return len(rows)

    async def head_waiter(self, user_id: uuid.UUID) -> Recording | None:
        return await self.session.scalar(
            select(Recording)
            .where(
                Recording.user_id == user_id,
                Recording.deleted_at.is_(None),
                Recording.status
                == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
            )
            .order_by(Recording.created_at, Recording.id)
            .limit(1)
        )

    async def wake_next(self, user_id: uuid.UUID) -> None:
        """Make the FIFO head due for a fresh LIVE check.

        A terminal recording never promotes from cached live_status. The Watch
        scheduler re-checks the source and only then calls promote_checked_room.
        """

        while True:
            recording = await self.head_waiter(user_id)
            if recording is None:
                return
            watch = await self.session.scalar(
                select(Watch).where(
                    Watch.user_id == user_id,
                    Watch.deleted_at.is_(None),
                    Watch.auto_record.is_(True),
                    Watch.status == WatchStatus.ACTIVE.value,
                    Watch.resolved_room_id == recording.source_value,
                )
            )
            if watch is not None:
                watch.next_check_at = utcnow()
                watch.scheduler_lease_id = None
                watch.scheduler_lease_expires_at = None
                await self.session.commit()
                return

            recording.status = RecordingStatus.MISSED_NO_CLOUD_SLOT.value
            recording.ended_at = utcnow()
            recording.actual_cost = 0
            recording.active_dedupe_key = None
            await append_event(
                self.session,
                recording,
                "recording.missed_no_cloud_slot",
            )
            await self.session.commit()

    async def promote_checked_room(
        self,
        *,
        user_id: uuid.UUID,
        room_id: str,
    ) -> Recording | None:
        """Promote only when the freshly checked room is the FIFO head."""

        entitlement = await EntitlementService(
            self.session,
            self.settings,
        ).get(user_id)
        if not entitlement.is_pro:
            return None

        active_values = [item.value for item in ACTIVE_RECORDING_STATUSES]
        active_count = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.user_id == user_id,
                    Recording.deleted_at.is_(None),
                    Recording.status.in_(active_values),
                )
            )
            or 0
        )
        if active_count >= entitlement.max_concurrent_cloud_recordings:
            return None

        recording = await self.session.scalar(
            select(Recording)
            .where(
                Recording.user_id == user_id,
                Recording.deleted_at.is_(None),
                Recording.status
                == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
            )
            .order_by(Recording.created_at, Recording.id)
            .limit(1)
            .with_for_update(skip_locked=True)
        )
        if recording is None or recording.source_value != room_id:
            await self.wake_next(user_id)
            return None

        watch = await self.session.scalar(
            select(Watch).where(
                Watch.user_id == user_id,
                Watch.deleted_at.is_(None),
                Watch.auto_record.is_(True),
                Watch.status == WatchStatus.ACTIVE.value,
                Watch.resolved_room_id == room_id,
            )
        )
        if watch is None:
            recording.status = RecordingStatus.MISSED_NO_CLOUD_SLOT.value
            recording.ended_at = utcnow()
            recording.actual_cost = 0
            recording.active_dedupe_key = None
            await append_event(
                self.session,
                recording,
                "recording.missed_no_cloud_slot",
            )
            await self.session.commit()
            await self.wake_next(user_id)
            return None

        max_duration = (
            recording.max_duration_seconds
            or self.settings.recording_max_duration_seconds
        )
        affordable = await CreditService(
            self.session
        ).affordable_duration_seconds(
            user_id=user_id,
            max_duration_seconds=max_duration,
        )
        if affordable <= 0:
            await self._pause_for_credit(watch)
            await self.session.commit()
            return None
        if affordable < max_duration:
            max_duration = affordable
            recording.max_duration_seconds = affordable

        try:
            reservation, estimated_max_cost = await CreditService(
                self.session
            ).reserve_recording(
                user_id=user_id,
                recording_id=recording.id,
                max_duration_seconds=max_duration,
            )
        except ApplicationError as exc:
            if exc.code != "INSUFFICIENT_CREDITS":
                raise
            await self._pause_for_credit(watch)
            await self.session.commit()
            return None

        recording.estimated_max_cost = estimated_max_cost
        recording.credit_reservation_id = str(reservation.id)
        recording.status = RecordingStatus.QUEUED.value
        await append_event(self.session, recording, "recording.queued")
        await self.outbox.enqueue(
            self.session,
            topic="recording.requested",
            aggregate_type="recording",
            aggregate_id=str(recording.id),
            payload={"recording_id": str(recording.id)},
        )
        await self.session.commit()
        await self.session.refresh(recording)
        return recording

    async def _pause_for_credit(self, watch: Watch) -> None:
        watch.status = WatchStatus.PAUSED_INSUFFICIENT_CREDIT.value
        watch.next_check_at = None
        watch.scheduler_lease_id = None
        watch.scheduler_lease_expires_at = None
        watch.last_error = "insufficient_credits"
        await self.session.flush()
