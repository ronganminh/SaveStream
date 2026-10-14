"""QA 2026-10-14: a job sat in `uploading` and nothing told an admin.

The upload is now retried as a whole, the storage client has short socket
timeouts, and recordings still processing/uploading past a threshold are
reported (ops alert + admin Recordings page)."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from datetime import timedelta

from sqlalchemy import select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.operations.service import OperationsService, evaluate_alerts
from app.application.recordings.service import RecordingService, append_event, utcnow
from app.application.recordings.stuck import find_stuck_uploads
from app.infrastructure.db.models import Base
from app.infrastructure.db.recording_models import Recording, RecordingArtifact, RecordingEvent
from app.infrastructure.db.session import Database
from app.infrastructure.recording import worker
from app.infrastructure.recording.media_probe import MediaInfo
from app.infrastructure.recording.runtime import RecordingRuntime
from app.infrastructure.storage.minio import MinioStorageClient
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings
from tests.test_recording_media_download import _seed_user
from tests.test_recording_worker_heartbeat import _Engine, _Gateway, _Redis, _Resolver


def _settings(tmp_path, name: str):
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}"),
        recording_temp_dir=str(tmp_path / "rec"),
        recording_upload_attempts=3,
        recording_upload_retry_seconds=0,
    )


async def _seed_recording(settings) -> uuid.UUID:
    database = Database(settings.database_url)
    try:
        async with database.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with database.session() as session:
            user = _seed_user(session, f"{uuid.uuid4().hex[:8]}@example.com")
            await session.commit()
            await session.refresh(user)
            await configure_test_pricing(session, credits_per_unit=1)
            await mark_test_user_paid(session, user.id)
            await grant_test_credits(session, user.id, 500)
            recording = await RecordingService(session, settings).create_for_user(
                user.id,
                CreateRecordingRequest(
                    source=Source(type="room_id", value="7695803833239358"),
                    max_duration_seconds=60,
                ),
                idempotency_key=str(uuid.uuid4()),
            )
            return recording.id
    finally:
        await database.close()


def _run_with_storage(tmp_path, monkeypatch, storage_cls, name: str):
    settings = _settings(tmp_path, name)
    monkeypatch.setattr(
        worker,
        "build_recording_runtime",
        lambda _settings: RecordingRuntime(resolver=_Resolver(), gateway=_Gateway()),
    )
    monkeypatch.setattr(worker, "RecordingEngine", _Engine)
    monkeypatch.setattr(worker, "MinioStorageClient", storage_cls)
    monkeypatch.setattr(worker, "SyncRedis", _Redis)
    monkeypatch.setattr(
        worker, "probe_media", lambda _path: MediaInfo(duration_ms=8000, width=720, height=1280)
    )
    recording_id = asyncio.run(_seed_recording(settings))
    asyncio.run(worker._run_recording_job(recording_id, settings))

    async def read() -> tuple[Recording, list[RecordingArtifact]]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                row = await session.get(Recording, recording_id)
                artifacts = list(
                    (
                        await session.scalars(
                            select(RecordingArtifact).where(
                                RecordingArtifact.recording_id == recording_id
                            )
                        )
                    ).all()
                )
                assert row is not None
                return row, artifacts
        finally:
            await database.close()

    return asyncio.run(read())


def test_upload_is_retried_and_the_recording_completes(tmp_path, monkeypatch) -> None:
    calls: list[str] = []

    class _FlakyStorage:
        def __init__(self, settings) -> None:
            del settings

        def upload_file(self, path, key, *, content_type) -> None:
            calls.append(key)
            if len(calls) < 3:
                raise TimeoutError("read timed out")

    row, artifacts = _run_with_storage(tmp_path, monkeypatch, _FlakyStorage, "retry.db")

    assert len(calls) == 3 and len(set(calls)) == 1
    assert row.status == "completed"
    assert len(artifacts) == 1


def test_upload_fails_cleanly_after_the_last_attempt(tmp_path, monkeypatch) -> None:
    calls: list[str] = []

    class _DeadStorage:
        def __init__(self, settings) -> None:
            del settings

        def upload_file(self, path, key, *, content_type) -> None:
            calls.append(key)
            raise ConnectionResetError("connection reset by peer")

    row, artifacts = _run_with_storage(tmp_path, monkeypatch, _DeadStorage, "dead.db")

    assert len(calls) == 3
    assert row.status == "failed"
    assert row.error_code == "SERVICE_UNAVAILABLE"
    assert "Artifact upload failed" in (row.error_message or "")
    assert artifacts == []


def test_storage_client_uses_short_socket_timeouts() -> None:
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        storage_connect_timeout_seconds=7,
        storage_read_timeout_seconds=42,
    )
    client = MinioStorageClient(settings).client
    timeout = client._http.connection_pool_kw["timeout"]
    assert (timeout.connect_timeout, timeout.read_timeout) == (7, 42)


def test_stuck_uploads_are_reported_to_admin_and_ops(tmp_path) -> None:
    settings = replace(
        _settings(tmp_path, "stuck.db"),
        recording_stuck_upload_seconds=1800,
    )

    async def run() -> None:
        stuck_id = await _seed_recording(settings)
        fresh_id = await _seed_recording(settings)
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                for recording_id, minutes_ago in ((stuck_id, 50), (fresh_id, 5)):
                    recording = await session.get(Recording, recording_id)
                    assert recording is not None
                    recording.status = "uploading"
                    # The heartbeat keeps updated_at fresh; detection must use the
                    # uploading event instead.
                    recording.updated_at = utcnow()
                    event = await append_event(session, recording, "recording.uploading")
                    event.created_at = utcnow() - timedelta(minutes=minutes_ago)
                await session.commit()

                stuck = await find_stuck_uploads(session, older_than_seconds=1800)
                assert [item.recording.id for item in stuck] == [stuck_id]

                snapshot = await OperationsService(session, settings).snapshot()
                assert snapshot.stuck_upload_recordings == 1
                codes = {alert.code for alert in evaluate_alerts(snapshot, settings)}
                assert "recordings_stuck_uploading" in codes

                # Once it completes it is no longer reported.
                done = await session.get(Recording, stuck_id)
                assert done is not None
                done.status = "completed"
                await session.commit()
                assert await find_stuck_uploads(session, older_than_seconds=1800) == []
                events = await session.scalar(
                    select(RecordingEvent).where(RecordingEvent.recording_id == stuck_id)
                )
                assert events is not None
        finally:
            await database.close()

    asyncio.run(run())
