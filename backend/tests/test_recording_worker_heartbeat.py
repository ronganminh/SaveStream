"""BUG-3 (QA 2026-10-14): a slow upload must not let a finished recording be
recovered as stale, re-run, and marked failed with STREAM_OFFLINE."""

from __future__ import annotations

import asyncio
import time
import uuid
from dataclasses import replace
from pathlib import Path

from sqlalchemy import select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.recordings.service import RecordingService, utcnow
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.session import Database
from app.infrastructure.recording import worker
from app.infrastructure.recording.runtime import ResolvedSource, RecordingRuntime
from engine import RecordingResult, StopReason
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings


class _Resolver:
    def resolve(self, source: Source) -> ResolvedSource:
        return ResolvedSource(username="v_nenee", room_id=source.value)

    def live_status(self, source: Source) -> tuple[ResolvedSource, bool]:
        return self.resolve(source), True


class _Gateway:
    def is_room_alive(self, room_id: str) -> bool:
        return True


class _Engine:
    def __init__(self, gateway, processor) -> None:
        del gateway, processor

    def record(self, request, *, should_stop, on_event) -> RecordingResult:
        del should_stop, on_event
        path = Path(request.output_dir) / "capture.mp4"
        path.write_bytes(b"\0" * 4096)
        return RecordingResult(
            source_path=path,
            artifact_path=path,
            bytes_recorded=4096,
            stop_reason=StopReason.STREAM_ENDED,
            discarded=False,
        )


class _Redis:
    @classmethod
    def from_url(cls, *args, **kwargs):
        return cls()

    def get(self, key):
        return None

    def delete(self, key):
        return 0

    def close(self):
        return None


def test_slow_upload_keeps_lease_and_completes(tmp_path, monkeypatch) -> None:
    settings = replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'worker.db'}"),
        recording_heartbeat_seconds=1,
        recording_stale_after_seconds=2,
        recording_temp_dir=str(tmp_path / "rec"),
    )
    stale_during_upload: list[list[str]] = []

    class _Storage:
        def __init__(self, settings) -> None:
            del settings

        def upload_file(self, path, key, *, content_type) -> None:
            # Longer than the stale threshold, like a multi-GB upload.
            time.sleep(3.5)
            stale_during_upload.append(asyncio.run(worker._recover_stale(settings)))

    monkeypatch.setattr(
        worker,
        "build_recording_runtime",
        lambda _settings: RecordingRuntime(resolver=_Resolver(), gateway=_Gateway()),
    )
    monkeypatch.setattr(worker, "RecordingEngine", _Engine)
    monkeypatch.setattr(worker, "MinioStorageClient", _Storage)
    monkeypatch.setattr(worker, "SyncRedis", _Redis)

    async def seed() -> uuid.UUID:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="worker@example.com",
                    normalized_email="worker@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
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

    recording_id = asyncio.run(seed())
    asyncio.run(worker._run_recording_job(recording_id, settings))

    assert stale_during_upload == [[]], "job was reported stale while uploading"

    async def read() -> tuple[Recording, int]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                row = await session.scalar(select(Recording).where(Recording.id == recording_id))
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
                return row, len(artifacts)
        finally:
            await database.close()

    row, artifacts = asyncio.run(read())
    assert row.status == "completed", (row.status, row.error_code, row.error_message)
    assert row.worker_attempts == 1
    assert artifacts == 1
    # The post-capture heartbeat must not bill upload time as recording time.
    assert row.duration_seconds < 3
