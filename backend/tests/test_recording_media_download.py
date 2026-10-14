"""QA 2026-10-14 (job d6b02069): the download opened the video in the app tab
under a UUID name, and the recording showed 12 s / no resolution for an
8.27 s 640x1280 file."""

from __future__ import annotations

import asyncio
import json
import shutil
import subprocess
import uuid
from dataclasses import replace
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import select

from app.api.routes.artifacts import create_download_url
from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.recordings.download import download_filename
from app.application.recordings.service import RecordingService, utcnow
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.session import Database
from app.infrastructure.recording import media_probe, worker
from app.infrastructure.recording.media_probe import MediaInfo, probe_media
from app.infrastructure.recording.runtime import RecordingRuntime
from app.infrastructure.storage.minio import MinioStorageClient
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings
from tests.test_recording_worker_heartbeat import _Engine, _Gateway, _Redis, _Resolver


def _seed_user(session, email: str) -> User:
    user = User(
        email=email,
        normalized_email=email,
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    return user


# --- (2) + (3): duration and frame size come from ffprobe -------------------


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg is not installed")
def test_probe_reads_real_duration_and_portrait_size(tmp_path) -> None:
    path = tmp_path / "portrait.mp4"
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=640x1280:rate=15",
            "-f", "lavfi", "-i", "sine=frequency=440",
            "-t", "2.5", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac",
            "-shortest", str(path),
        ],
        check=True,
    )

    info = probe_media(path)

    assert info.width == 640 and info.height == 1280
    assert info.duration_ms is not None and abs(info.duration_ms - 2500) < 150
    assert info.duration_seconds in (2, 3)


def test_probe_swaps_size_for_rotated_video_and_survives_bad_files(tmp_path, monkeypatch) -> None:
    payload = {
        "format": {"duration": "8.270000"},
        "streams": [
            {"codec_type": "audio"},
            {
                "codec_type": "video",
                "width": 1280,
                "height": 640,
                "side_data_list": [{"rotation": -90}],
            },
        ],
    }
    monkeypatch.setattr(
        media_probe.subprocess,
        "run",
        lambda *a, **k: SimpleNamespace(stdout=json.dumps(payload).encode()),
    )
    info = probe_media(tmp_path / "x.mp4")
    assert (info.duration_ms, info.width, info.height) == (8270, 640, 1280)
    assert info.duration_seconds == 8

    def fail(*a, **k):
        raise subprocess.CalledProcessError(1, "ffprobe")

    monkeypatch.setattr(media_probe.subprocess, "run", fail)
    assert probe_media(tmp_path / "missing.mp4") == MediaInfo()


def test_worker_stores_probed_duration_and_size_not_wall_clock(tmp_path, monkeypatch) -> None:
    settings = replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'media.db'}"),
        recording_temp_dir=str(tmp_path / "rec"),
    )

    class _Storage:
        def __init__(self, settings) -> None:
            del settings

        def upload_file(self, path, key, *, content_type) -> None:
            return None

    monkeypatch.setattr(
        worker,
        "build_recording_runtime",
        lambda _settings: RecordingRuntime(resolver=_Resolver(), gateway=_Gateway()),
    )
    monkeypatch.setattr(worker, "RecordingEngine", _Engine)
    monkeypatch.setattr(worker, "MinioStorageClient", _Storage)
    monkeypatch.setattr(worker, "SyncRedis", _Redis)
    monkeypatch.setattr(
        worker, "probe_media", lambda _path: MediaInfo(duration_ms=8270, width=640, height=1280)
    )
    # The fake capture takes ~0 s of wall clock; the stored duration must be
    # the probed 8.27 s (rounded), not the job's own clock.

    async def seed() -> uuid.UUID:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = _seed_user(session, "media@example.com")
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

    async def read() -> tuple[Recording, RecordingArtifact]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                row = await session.get(Recording, recording_id)
                artifact = await session.scalar(
                    select(RecordingArtifact).where(RecordingArtifact.recording_id == recording_id)
                )
                assert row is not None and artifact is not None
                return row, artifact
        finally:
            await database.close()

    row, artifact = asyncio.run(read())
    assert row.status == "completed"
    assert row.duration_seconds == 8
    assert (artifact.duration_ms, artifact.width, artifact.height) == (8270, 640, 1280)


# --- (1): download is an attachment with a readable name --------------------


def test_download_filename_is_readable_and_header_safe() -> None:
    recording = Recording(
        source_value="@p.c.dat25",
        resolved_username="p.c.dat25",
        started_at=datetime(2026, 10, 14, 14, 6, tzinfo=timezone.utc),
    )
    assert download_filename(recording) == "p.c.dat25_2026-10-14_1406.mp4"
    assert download_filename(recording, tz_offset_minutes=420) == "p.c.dat25_2026-10-14_2106.mp4"

    odd = Recording(
        source_value='https://www.tiktok.com/@a"b;c/live',
        resolved_username=None,
        started_at=datetime(2026, 1, 2, 3, 4, tzinfo=timezone.utc),
    )
    name = download_filename(odd)
    assert name.endswith("_2026-01-02_0304.mp4")
    assert all(ch.isalnum() or ch in "._-" for ch in name)


def test_minio_signs_content_disposition_into_the_url(monkeypatch) -> None:
    client = MinioStorageClient(identity_settings("sqlite+aiosqlite:///:memory:"))
    calls: list[dict] = []

    def presign(bucket, key, *, expires, response_headers=None):
        calls.append({"key": key, "response_headers": response_headers})
        return "https://r2.example/signed"

    monkeypatch.setattr(client.client, "presigned_get_object", presign)
    client.presigned_get_url("k.mp4")
    client.presigned_get_url("k.mp4", content_disposition='attachment; filename="a.mp4"')

    assert calls[0]["response_headers"] is None  # playback stays inline
    assert calls[1]["response_headers"] == {
        "response-content-disposition": 'attachment; filename="a.mp4"',
        "response-content-type": "video/mp4",
    }


def test_download_url_endpoint_requests_attachment_with_readable_name(tmp_path) -> None:
    settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'download.db'}")
    signed: list[tuple[str, str | None]] = []

    class _Minio:
        def presigned_get_url(self, key, *, content_disposition=None):
            signed.append((key, content_disposition))
            return "https://r2.example/signed"

    async def run() -> None:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = _seed_user(session, "download@example.com")
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id)
                principal = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))
                service = RecordingService(session, settings)
                recording = await service.create(
                    principal,
                    CreateRecordingRequest(source=Source(type="username", value="p.c.dat25")),
                    idempotency_key=str(uuid.uuid4()),
                )
                recording.resolved_username = "p.c.dat25"
                recording.started_at = datetime(2026, 10, 14, 14, 6, tzinfo=timezone.utc)
                artifact = RecordingArtifact(
                    recording_id=recording.id,
                    storage_key=f"users/{user.id}/recordings/{recording.id}/{uuid.uuid4()}.mp4",
                    container="mp4",
                    size_bytes=123,
                    checksum_sha256="a" * 64,
                )
                session.add(artifact)
                await session.commit()
                request = SimpleNamespace(
                    app=SimpleNamespace(state=SimpleNamespace(minio=_Minio(), settings=settings))
                )
                for disposition in ("inline", "attachment"):
                    await create_download_url(
                        str(artifact.id),
                        request,  # type: ignore[arg-type]
                        disposition=disposition,  # type: ignore[arg-type]
                        tz_offset_minutes=420,
                        principal=principal,
                        service=service,
                    )
        finally:
            await database.close()

    asyncio.run(run())

    assert signed[0][1] is None
    assert signed[1][1] == 'attachment; filename="p.c.dat25_2026-10-14_2106.mp4"'
    assert Path(signed[1][0]).suffix == ".mp4"


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg is not installed")
def test_probe_reports_the_largest_size_when_the_stream_switches_resolution(tmp_path) -> None:
    """QA 2026-10-14: f9d4ebc5 starts at 640x1280 and switches to 720x1280
    (TikTok adaptive bitrate); the MP4 header only shows the first size."""
    parts = []
    for index, size in enumerate(("640x1280", "720x1280")):
        part = tmp_path / f"part{index}.ts"
        subprocess.run(
            [
                "ffmpeg", "-v", "error", "-f", "lavfi", "-i", f"testsrc=size={size}:rate=15",
                "-t", "4", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-g", "15",
                "-output_ts_offset", str(4 * index), "-f", "mpegts", str(part),
            ],
            check=True,
        )
        parts.append(part.read_bytes())
    joined = tmp_path / "switching.ts"
    joined.write_bytes(b"".join(parts))
    path = tmp_path / "switching.mp4"
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(joined), "-c", "copy", str(path)], check=True
    )

    info = probe_media(path)

    assert (info.width, info.height) == (720, 1280)
    assert info.duration_ms is not None and abs(info.duration_ms - 8000) < 600
