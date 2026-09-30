from __future__ import annotations

import random
import uuid
from collections.abc import Callable, Protocol
from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.recordings.service import RecordingService
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES
from app.domain.watches.state import WatchStatus
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.settings import AppSettings

from .service import aware, utcnow


@dataclass(frozen=True, slots=True)
class WatchClaim:
    watch_id: uuid.UUID
    lease_id: uuid.UUID


@dataclass(frozen=True, slots=True)
class WatchLiveResult:
    username: str
    room_id: str
    is_live: bool


class WatchLiveChecker(Protocol):
    async def check(self, source: Source) -> WatchLiveResult: ...


class WatchScheduler:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        *,
        random_fn: Callable[[], float] = random.random,
    ) -> None:
        self.session = session
        self.settings = settings
        self.random_fn = random_fn

    def _jitter(self, seconds: float) -> timedelta:
        ratio = self.settings.watch_jitter_ratio
        factor = 1.0 + ((self.random_fn() * 2.0) - 1.0) * ratio
        return timedelta(seconds=max(1.0, seconds * factor))

    def _error_delay(self, failure_count: int) -> timedelta:
        seconds = min(
            self.settings.watch_error_backoff_max_seconds,
            self.settings.watch_error_backoff_base_seconds
            * (2 ** max(failure_count - 1, 0)),
        )
        return self._jitter(float(seconds))

    async def claim_due(self) -> list[WatchClaim]:
        now = utcnow()
        statement = (
            select(Watch)
            .where(
                Watch.deleted_at.is_(None),
                Watch.status == WatchStatus.ACTIVE.value,
                Watch.next_check_at.is_not(None),
                Watch.next_check_at <= now,
                or_(
                    Watch.scheduler_lease_id.is_(None),
                    Watch.scheduler_lease_expires_at.is_(None),
                    Watch.scheduler_lease_expires_at <= now,
                ),
            )
            .order_by(Watch.next_check_at, Watch.id)
            .limit(self.settings.watch_scheduler_batch_size)
            .with_for_update(skip_locked=True)
        )
        rows = list((await self.session.scalars(statement)).all())
        claims: list[WatchClaim] = []
        lease_expires = now + timedelta(seconds=self.settings.watch_scheduler_lease_seconds)
        for watch in rows:
            lease_id = uuid.uuid4()
            watch.scheduler_lease_id = lease_id
            watch.scheduler_lease_expires_at = lease_expires
            watch.next_check_at = lease_expires
            claims.append(WatchClaim(watch_id=watch.id, lease_id=lease_id))
        await self.session.commit()
        return claims

    async def process_claim(
        self,
        claim: WatchClaim,
        checker: WatchLiveChecker,
    ) -> None:
        watch = await self.session.scalar(
            select(Watch).where(
                Watch.id == claim.watch_id,
                Watch.scheduler_lease_id == claim.lease_id,
                Watch.deleted_at.is_(None),
            )
        )
        if watch is None or watch.status != WatchStatus.ACTIVE.value:
            return

        now = utcnow()
        source = Source.model_validate(
            {"type": watch.source_type, "value": watch.source_value}
        )
        try:
            result = await checker.check(source)
        except Exception as exc:
            await self._record_failure(watch, now, exc)
            return

        watch.last_checked_at = now
        watch.failure_count = 0
        watch.last_error = None
        watch.resolved_username = result.username
        watch.resolved_room_id = result.room_id
        watch.live_status = "live" if result.is_live else "offline"
        watch.scheduler_lease_id = None
        watch.scheduler_lease_expires_at = None
        if result.is_live:
            watch.last_live_at = now
            watch.next_check_at = now + self._jitter(
                float(self.settings.watch_live_check_seconds)
            )
        else:
            watch.next_check_at = now + self._jitter(
                float(self.settings.watch_offline_check_seconds)
            )
        await self.session.commit()

        if result.is_live and watch.auto_record:
            await self._auto_record(watch, result.room_id)

    async def _record_failure(
        self,
        watch: Watch,
        now,
        exc: Exception,
    ) -> None:
        watch.last_checked_at = now
        watch.live_status = "unknown"
        watch.failure_count += 1
        watch.last_error = (str(exc) or type(exc).__name__)[:1000]
        watch.scheduler_lease_id = None
        watch.scheduler_lease_expires_at = None
        if watch.failure_count >= self.settings.watch_error_pause_threshold:
            watch.status = WatchStatus.PAUSED_ERROR.value
            watch.next_check_at = None
        else:
            watch.next_check_at = now + self._error_delay(watch.failure_count)
        await self.session.commit()

    async def _auto_record(self, watch: Watch, room_id: str) -> None:
        active_values = [status.value for status in ACTIVE_RECORDING_STATUSES]
        active_count = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.user_id == watch.user_id,
                    Recording.deleted_at.is_(None),
                    Recording.status.in_(active_values),
                )
            )
            or 0
        )
        if active_count >= self.settings.watch_max_concurrent_recordings_per_user:
            return

        payload = CreateRecordingRequest(
            source=Source(type="room_id", value=room_id),
            max_duration_seconds=None,
            quality="best",
            container="mp4",
        )
        idempotency_key = str(
            uuid.uuid5(
                uuid.NAMESPACE_URL,
                f"savestream:watch-room:{watch.user_id}:{room_id}",
            )
        )
        try:
            await RecordingService(self.session, self.settings).create_for_user(
                watch.user_id,
                payload,
                idempotency_key=idempotency_key,
            )
        except ApplicationError as exc:
            if exc.code == "RECORDING_ALREADY_ACTIVE":
                return
            raise
