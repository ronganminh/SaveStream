from __future__ import annotations

import asyncio
import hashlib
import logging
import shutil
import threading
import time
import uuid
from pathlib import Path
from datetime import timedelta

from redis import Redis as SyncRedis
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError

from app.api.schemas.recordings import Source
from app.application.analytics import record_first_recording_event
from app.application.credits.service import CreditService
from app.application.recordings.retention import has_paid_purchase
from app.application.notifications.service import (
    ensure_cloud_minutes_exhausted_notification,
    ensure_credits_low_notification,
)
from app.application.recordings.service import (
    RecordingStateStore,
    append_event,
    aware,
    utcnow,
)
from app.domain.recordings.state import (
    ACTIVE_RECORDING_STATUSES,
    RecordingStatus,
    transition,
)
from app.infrastructure.db.admin_models import AdminStorageRun
from app.infrastructure.db.recording_models import (
    Recording,
    RecordingArtifact,
)
from app.infrastructure.db.session import Database
from app.infrastructure.recording.media_probe import (
    extract_thumbnail,
    probe_media,
    thumbnail_key_for,
)
from app.infrastructure.recording.runtime import (
    AtomicFFmpegMediaProcessor,
    build_recording_runtime,
)
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings, get_app_settings
from engine import EngineEvent, RecordingEngine, RecordingRequest, StopReason

_CANCEL_PREFIX = "savestream:recording:stop:"

logger = logging.getLogger("savestream.recording.worker")


def _checksum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _ensure_stop_requested_transition(recording: Recording) -> bool:
    """Normalize a user-stopped capture before its terminal transition.

    Returns True when this worker had to persist the intermediate transition.
    The API normally writes it first, but Redis cancellation can reach the
    capture loop before that database update is visible to this session.
    """
    current_status = RecordingStatus(recording.status)
    if current_status is RecordingStatus.STOP_REQUESTED:
        return False
    recording.status = transition(
        current_status,
        RecordingStatus.STOP_REQUESTED,
    ).value
    return True


async def _upload_with_retry(
    storage: MinioStorageClient,
    path: Path,
    storage_key: str,
    *,
    attempts: int,
    retry_seconds: int,
) -> None:
    """Upload the finished file, retrying the whole upload on failure.

    The heartbeat keeps the lease alive meanwhile, so the recording stays in
    `uploading` instead of being recovered (and re-recorded) by another worker.
    """
    for attempt in range(1, attempts + 1):
        try:
            await asyncio.to_thread(
                storage.upload_file,
                path,
                storage_key,
                content_type="video/mp4",
            )
            return
        except Exception:
            if attempt >= attempts:
                raise
            logger.warning(
                "artifact upload failed, retrying key=%s attempt=%s/%s",
                storage_key,
                attempt,
                attempts,
                exc_info=True,
            )
            await asyncio.sleep(retry_seconds * attempt)


async def _make_thumbnail(
    storage: MinioStorageClient,
    source: Path,
    storage_key: str,
    *,
    duration_ms: int | None,
) -> str | None:
    """One JPEG frame next to the video. Best effort: the recording never
    fails because of its thumbnail; the library shows a gradient instead."""
    target = source.with_suffix(".thumb.jpg")
    key = thumbnail_key_for(storage_key)
    try:
        if not await asyncio.to_thread(
            extract_thumbnail, source, target, duration_ms=duration_ms
        ):
            return None
        await asyncio.to_thread(storage.upload_file, target, key, content_type="image/jpeg")
        return key
    except Exception:
        logger.warning("thumbnail failed key=%s", key, exc_info=True)
        return None
    finally:
        target.unlink(missing_ok=True)


async def _run_recording_job(recording_id: uuid.UUID, settings: AppSettings) -> None:
    database = Database(settings.database_url)
    storage = MinioStorageClient(settings)
    sync_redis = SyncRedis.from_url(settings.redis_url, decode_responses=True)
    temp_dir = Path(settings.recording_temp_dir) / str(recording_id)
    temp_dir.mkdir(parents=True, exist_ok=True)
    stop_event = threading.Event()

    try:
        async with database.session() as session:
            store = RecordingStateStore(session, settings)
            claimed = await store.claim(recording_id)
            if claimed is None:
                return
            recording, lease_id = claimed

            source = Source.model_validate(
                {"type": recording.source_type, "value": recording.source_value}
            )
            runtime = build_recording_runtime(settings)
            try:
                resolved = await asyncio.to_thread(runtime.resolver.resolve, source)
                recording.resolved_username = resolved.username
                recording.room_id = resolved.room_id
                alive = await asyncio.to_thread(
                    runtime.gateway.is_room_alive,
                    resolved.room_id,
                )
                if not alive:
                    recording.status = transition(
                        RecordingStatus(recording.status),
                        RecordingStatus.WAITING_LIVE,
                    ).value
                    await append_event(session, recording, "recording.waiting_live")
                    await session.commit()
                    await store.fail(
                        recording,
                        code="STREAM_OFFLINE",
                        message="The source is currently offline",
                        retryable=False,
                    )
                    return
                await record_first_recording_event(
                    session,
                    recording,
                    event="first_recording_started",
                    properties={},
                    settings=settings,
                )
                await store.set_status(
                    recording,
                    RecordingStatus.RECORDING,
                    "recording.started",
                )
            except Exception as exc:
                await store.fail(
                    recording,
                    code="STREAM_UNAVAILABLE",
                    message=str(exc) or "Unable to resolve stream",
                    retryable=True,
                )
                return

            latest_bytes = 0
            started_monotonic = time.monotonic()
            # Set once the capture ends; afterwards the heartbeat only keeps the
            # lease alive and no longer grows duration_seconds.
            capture_done = False

            def on_engine_event(event: EngineEvent) -> None:
                nonlocal latest_bytes
                latest_bytes = max(latest_bytes, event.bytes_recorded)

            def should_stop() -> bool:
                if stop_event.is_set():
                    return True
                try:
                    return bool(sync_redis.get(f"{_CANCEL_PREFIX}{recording_id}"))
                except Exception:
                    return False

            async def heartbeat_loop() -> None:
                # Own session: the job keeps using `session` for status changes
                # while this loop runs. The heartbeat must also cover
                # processing, checksum and upload, which take minutes for a
                # long livestream; otherwise recover_stale re-enqueues the job,
                # a second attempt finds the creator offline and marks a
                # complete recording as failed (BUG-3, QA 2026-10-14).
                async with database.session() as heartbeat_session:
                    heartbeat_store = RecordingStateStore(heartbeat_session, settings)
                    while True:
                        await asyncio.sleep(settings.recording_heartbeat_seconds)
                        current = await heartbeat_session.get(Recording, recording_id)
                        if current is not None:
                            await heartbeat_session.refresh(current)
                        if current is None or current.worker_lease_id != lease_id:
                            stop_event.set()
                            return
                        if current.status == RecordingStatus.STOP_REQUESTED.value:
                            stop_event.set()
                        if capture_done:
                            await heartbeat_store.heartbeat(recording_id, lease_id)
                            continue
                        elapsed = int(time.monotonic() - started_monotonic)
                        await heartbeat_store.heartbeat(
                            recording_id,
                            lease_id,
                            bytes_recorded=latest_bytes,
                            duration_seconds=max(elapsed, 0),
                            event_type="recording.progress",
                        )

            heartbeat_task = asyncio.create_task(heartbeat_loop())
            try:
                engine = RecordingEngine(
                    runtime.gateway,
                    AtomicFFmpegMediaProcessor(),
                )
                try:
                    result = await asyncio.to_thread(
                        engine.record,
                        RecordingRequest(
                            username=resolved.username,
                            room_id=resolved.room_id,
                            output_dir=temp_dir,
                            duration_seconds=recording.max_duration_seconds,
                        ),
                        should_stop=should_stop,
                        on_event=on_engine_event,
                    )
                except Exception as exc:
                    await store.fail(
                        recording,
                        code="STREAM_UNAVAILABLE",
                        message=str(exc) or "Recording failed",
                        retryable=True,
                    )
                    return
                capture_done = True

                # The stop endpoint updates this row in a different session while
                # the recorder is blocked in the capture thread.  Refresh before
                # deciding the terminal transition; otherwise this session can
                # still hold `recording` and incorrectly attempt
                # `recording -> stopped`, rolling back the uploaded artifact.
                await session.refresh(recording)
                recording.bytes_recorded = result.bytes_recorded
                recording.duration_seconds = max(
                    recording.duration_seconds,
                    int(time.monotonic() - started_monotonic),
                )
                if result.discarded or result.artifact_path is None:
                    await store.fail(
                        recording,
                        code="STREAM_UNAVAILABLE",
                        message=result.error or "Recording produced no valid media",
                        retryable=True,
                    )
                    return

                stopped_by_request = (
                    result.stop_reason is StopReason.USER_REQUESTED
                    or recording.status == RecordingStatus.STOP_REQUESTED.value
                )
                if stopped_by_request:
                    if _ensure_stop_requested_transition(recording):
                        await append_event(
                            session,
                            recording,
                            "recording.stop_requested",
                        )
                else:
                    await store.set_status(
                        recording,
                        RecordingStatus.PROCESSING,
                        "recording.processing",
                    )
                    await store.set_status(
                        recording,
                        RecordingStatus.UPLOADING,
                        "recording.uploading",
                    )

                artifact_id = uuid.uuid4()
                storage_key = f"users/{recording.user_id}/recordings/{recording.id}/{artifact_id}.mp4"
                checksum = await asyncio.to_thread(_checksum, result.artifact_path)
                size_bytes = result.artifact_path.stat().st_size
                # Real media length and frame size; the job's wall clock also counts
                # connecting and finalizing, so it overstates the video.
                media = await asyncio.to_thread(probe_media, result.artifact_path)
                if media.duration_seconds is not None:
                    recording.duration_seconds = media.duration_seconds
                if recording.max_duration_seconds:
                    # Capture stops at the cap (e.g. when the credits run out).
                    recording.duration_seconds = min(
                        recording.duration_seconds, recording.max_duration_seconds
                    )
                try:
                    await _upload_with_retry(
                        storage,
                        result.artifact_path,
                        storage_key,
                        attempts=settings.recording_upload_attempts,
                        retry_seconds=settings.recording_upload_retry_seconds,
                    )
                except Exception as exc:
                    await store.fail(
                        recording,
                        code="SERVICE_UNAVAILABLE",
                        message=f"Artifact upload failed: {exc}",
                        retryable=True,
                    )
                    return

                thumbnail_key = await _make_thumbnail(
                    storage,
                    result.artifact_path,
                    storage_key,
                    duration_ms=media.duration_ms,
                )
                session.add(
                    RecordingArtifact(
                        id=artifact_id,
                        recording_id=recording.id,
                        kind="video",
                        container="mp4",
                        storage_key=storage_key,
                        size_bytes=size_bytes,
                        checksum_sha256=checksum,
                        duration_ms=media.duration_ms,
                        width=media.width,
                        height=media.height,
                        thumbnail_key=thumbnail_key,
                    )
                )
                credit_service = CreditService(session)
                actual_cost = await credit_service.settle_recording(
                    recording_id=recording.id,
                    duration_seconds=recording.duration_seconds,
                    bytes_recorded=recording.bytes_recorded,
                )
                if actual_cost > 0:
                    balance = await credit_service.balance(recording.user_id)
                    if balance.posted == 0:
                        await ensure_cloud_minutes_exhausted_notification(
                            session,
                            user_id=recording.user_id,
                            recording_id=recording.id,
                            trial=not await has_paid_purchase(session, recording.user_id),
                        )
                    else:
                        # One notice a day once an hour or less is left.
                        await ensure_credits_low_notification(
                            session,
                            user_id=recording.user_id,
                            available=balance.available,
                            usage_day=utcnow().date(),
                        )
                await record_first_recording_event(
                    session,
                    recording,
                    event="first_recording_ready",
                    properties={
                        "duration_seconds": recording.duration_seconds,
                        "credits_charged": actual_cost,
                    },
                    settings=settings,
                )
                target = RecordingStatus.STOPPED if stopped_by_request else RecordingStatus.COMPLETED
                recording.status = transition(
                    RecordingStatus(recording.status),
                    target,
                ).value
                recording.actual_cost = actual_cost
                recording.ended_at = utcnow()
                recording.active_dedupe_key = None
                recording.worker_lease_id = None
                recording.heartbeat_at = utcnow()
                await append_event(
                    session,
                    recording,
                    "recording.stopped" if target is RecordingStatus.STOPPED else "recording.completed",
                )
                await session.commit()
                from app.application.recordings.cloud_slots import CloudSlotQueueService

                await CloudSlotQueueService(
                    session,
                    settings,
                ).wake_next(recording.user_id)
                result.artifact_path.unlink(missing_ok=True)
                result.source_path.unlink(missing_ok=True)
                try:
                    sync_redis.delete(f"{_CANCEL_PREFIX}{recording_id}")
                except Exception:
                    pass
            finally:
                heartbeat_task.cancel()
                await asyncio.gather(heartbeat_task, return_exceptions=True)
    finally:
        sync_redis.close()
        await database.close()


async def _cleanup_recording(recording_id: uuid.UUID, settings: AppSettings) -> None:
    database = Database(settings.database_url)
    storage = MinioStorageClient(settings)
    try:
        async with database.session() as session:
            recording = await session.get(Recording, recording_id)
            if recording is None or recording.deleted_at is None:
                return
            artifacts = list(
                (
                    await session.scalars(
                        select(RecordingArtifact).where(
                            RecordingArtifact.recording_id == recording_id,
                            RecordingArtifact.deleted_at.is_(None),
                        )
                    )
                ).all()
            )
            run = AdminStorageRun(
                kind="recording_cleanup",
                status="running",
                scanned_count=len(artifacts),
                details={"recording_id": str(recording_id)},
                started_at=utcnow(),
            )
            session.add(run)
            deleted_count = 0
            for artifact in artifacts:
                try:
                    await asyncio.to_thread(storage.remove, artifact.storage_key)
                except Exception:
                    continue
                if artifact.thumbnail_key:
                    try:
                        await asyncio.to_thread(storage.remove, artifact.thumbnail_key)
                    except Exception:
                        logger.warning("thumbnail delete failed key=%s", artifact.thumbnail_key)
                artifact.deleted_at = utcnow()
                deleted_count += 1
            run.deleted_count = deleted_count
            run.status = "completed"
            run.completed_at = utcnow()
            await session.commit()
        shutil.rmtree(
            Path(settings.recording_temp_dir) / str(recording_id),
            ignore_errors=True,
        )
    finally:
        await database.close()


async def _recover_stale(settings: AppSettings) -> list[str]:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            stale_before = utcnow() - timedelta(seconds=settings.recording_stale_after_seconds)
            active_values = [item.value for item in ACTIVE_RECORDING_STATUSES]
            rows = list(
                (
                    await session.scalars(
                        select(Recording).where(
                            Recording.deleted_at.is_(None),
                            Recording.status.in_(active_values),
                            or_(
                                Recording.heartbeat_at.is_(None),
                                Recording.heartbeat_at < stale_before,
                            ),
                        )
                    )
                ).all()
            )
            return [str(item.id) for item in rows]
    finally:
        await database.close()


def run_recording_job(recording_id: str) -> None:
    asyncio.run(_run_recording_job(uuid.UUID(recording_id), get_app_settings()))


def cleanup_recording(recording_id: str) -> None:
    asyncio.run(_cleanup_recording(uuid.UUID(recording_id), get_app_settings()))


def recover_stale_recordings() -> list[str]:
    return asyncio.run(_recover_stale(get_app_settings()))
