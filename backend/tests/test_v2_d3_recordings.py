from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.application.admin.recordings_d3 import AdminRecordingService
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.admin_models import AdminWatchCheckMetric
from app.infrastructure.db.models import Base, OutboxEvent, User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def test_d3_admin_recording_filters_actions_and_retention(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd3-recordings.db'}"
    settings = identity_settings(database_url)

    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = User(
                    email="d3-user@example.com",
                    normalized_email="d3-user@example.com",
                    role="user",
                )
                session.add(user)
                await session.flush()

                now = datetime.now(timezone.utc)
                active = Recording(
                    user_id=user.id,
                    source_type="username",
                    source_value="lina-live",
                    resolved_username="lina-live",
                    status=RecordingStatus.QUEUED.value,
                    quality="best",
                    container="mp4",
                    created_at=now - timedelta(minutes=5),
                )
                completed = Recording(
                    user_id=user.id,
                    source_type="username",
                    source_value="other-live",
                    resolved_username="other-live",
                    status=RecordingStatus.COMPLETED.value,
                    quality="best",
                    container="mp4",
                    ended_at=now - timedelta(minutes=1),
                    created_at=now - timedelta(minutes=10),
                )
                live_recording = Recording(
                    user_id=user.id,
                    source_type="username",
                    source_value="capacity-live",
                    resolved_username="capacity-live",
                    status=RecordingStatus.RECORDING.value,
                    quality="best",
                    container="mp4",
                    started_at=now - timedelta(minutes=30),
                    created_at=now - timedelta(minutes=31),
                )
                waiting = Recording(
                    user_id=user.id,
                    source_type="room_id",
                    source_value="room-queue",
                    resolved_username="queued-live",
                    status=RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
                    quality="best",
                    container="mp4",
                    created_at=now - timedelta(minutes=2),
                )
                session.add_all([active, completed, live_recording, waiting])
                await session.flush()
                artifact = RecordingArtifact(
                    recording_id=completed.id,
                    kind="video",
                    container="mp4",
                    storage_key="recordings/d3/video.mp4",
                    size_bytes=1234,
                    checksum_sha256="a" * 64,
                )
                watch_a = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="lina-live",
                    resolved_username="lina-live",
                    status="active",
                    live_status="offline",
                    auto_record=True,
                    failure_count=0,
                    last_checked_at=now - timedelta(seconds=10),
                )
                watch_b = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="lina-live",
                    resolved_username="lina-live",
                    status="paused_error",
                    live_status="unknown",
                    auto_record=False,
                    failure_count=3,
                    last_error="resolver_failed",
                    last_checked_at=now - timedelta(seconds=20),
                )
                session.add_all(
                    [
                        artifact,
                        watch_a,
                        watch_b,
                        AdminWatchCheckMetric(
                            watch_id=watch_a.id,
                            success=True,
                            latency_ms=120,
                            checked_at=now - timedelta(minutes=20),
                        ),
                        AdminWatchCheckMetric(
                            watch_id=watch_b.id,
                            success=False,
                            latency_ms=240,
                            error="resolver_failed",
                            checked_at=now - timedelta(minutes=10),
                        ),
                    ]
                )
                await session.commit()

                service = AdminRecordingService(session, settings)
                items, cursor, has_more = await service.list_recordings(
                    limit=20,
                    cursor=None,
                    user_id=user.id,
                    channel="lina",
                    status=RecordingStatus.QUEUED.value,
                    created_from=now - timedelta(hours=1),
                    created_to=now,
                    sort_order="desc",
                )
                assert [item.id for item in items] == [active.id]
                assert cursor is None
                assert has_more is False

                stopped, previous = await service.stop_recording(str(active.id))
                assert previous is RecordingStatus.QUEUED
                assert stopped.status == RecordingStatus.STOP_REQUESTED.value

                new_expiry = now + timedelta(days=45)
                retained, previous_expiry = await service.extend_retention(
                    str(completed.id),
                    expires_at=new_expiry,
                )
                assert previous_expiry is None
                assert retained.retention_expires_at == new_expiry

                playback = await service.playback_artifact(str(completed.id))
                assert playback.id == artifact.id

                queue_rows, queue_cursor, queue_more = await service.list_waiting_queue(
                    limit=20,
                    cursor=None,
                )
                assert [row[0].id for row in queue_rows] == [waiting.id]
                assert queue_rows[0][1] == user.email
                assert queue_cursor is None
                assert queue_more is False

                watch_rows, watch_cursor, watch_more = await service.list_watch_channels(
                    limit=20,
                    cursor=None,
                )
                assert len(watch_rows) == 1
                assert watch_rows[0]["channel"] == "lina-live"
                assert watch_rows[0]["followers"] == 2
                assert watch_rows[0]["auto_record_count"] == 1
                assert watch_rows[0]["paused_count"] == 1
                assert watch_rows[0]["failing_count"] == 1
                assert watch_rows[0]["max_failure_count"] == 3
                assert watch_cursor is None
                assert watch_more is False

                detector = await service.detector_metrics()
                assert detector["last_run_at"] is not None
                assert detector["failure_rate_1h"] == 0.5
                assert detector["average_latency_ms_1h"] == 180

                capacity = await service.capacity_metrics()
                assert capacity["current_in_use"] == 1
                assert capacity["global_limit"] == 6
                assert max(
                    point["max_concurrent"] for point in capacity["hourly"]
                ) >= 1

                deleted = await service.delete_recording(str(completed.id))
                assert deleted.deleted_at is not None
                assert deleted.cleanup_requested_at is not None

                await session.commit()
                cleanup = await session.scalar(
                    select(OutboxEvent).where(
                        OutboxEvent.topic == "recording.cleanup",
                        OutboxEvent.aggregate_id == str(completed.id),
                    )
                )
                assert cleanup is not None
        finally:
            await database.close()

    asyncio.run(run())
