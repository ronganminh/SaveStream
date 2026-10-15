"""Library thumbnails: one JPEG frame per recording, made after upload,
backfilled for old recordings, served through short-lived signed URLs."""

from __future__ import annotations

import asyncio
import shutil
import subprocess
import uuid
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import select

from app.api.routes.recordings import get_recording
from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.recordings.service import RecordingService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base
from app.infrastructure.db.recording_models import RecordingArtifact
from app.infrastructure.db.session import Database
from app.infrastructure.recording import worker
from app.infrastructure.recording.backfill_media import backfill_thumbnails
from app.infrastructure.recording.media_probe import (
    extract_thumbnail,
    thumbnail_key_for,
    thumbnail_offset_seconds,
)
from app.infrastructure.storage.media_urls import signed_media_url, stable_expiry
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings
from tests.test_recording_media_download import _seed_user

JPEG = b"\xff\xd8\xff\xe0fake-jpeg"


class _Storage:
    def __init__(self) -> None:
        self.uploads: dict[str, tuple[bytes, str]] = {}

    def upload_file(self, path, key, *, content_type) -> None:
        self.uploads[key] = (Path(path).read_bytes(), content_type)

    def presigned_get_url(self, key, *, content_disposition=None) -> str:
        return f"https://r2.example/{key}?sig=1"

    def thumbnail_url(self, key) -> str:
        return f"https://media.example/o/{key}?e=1&s=x"


def test_key_and_offset_rules() -> None:
    assert thumbnail_key_for("users/u/recordings/r/a1.mp4") == "users/u/recordings/r/a1.jpg"
    assert thumbnail_offset_seconds(None) == 1.0
    assert thumbnail_offset_seconds(3_000) == 1.0  # a third of a short clip
    assert thumbnail_offset_seconds(3_600_000) == 10.0  # capped for long LIVEs


@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg is not installed")
def test_extract_thumbnail_writes_a_small_jpeg(tmp_path) -> None:
    video = tmp_path / "v.mp4"
    subprocess.run(
        [
            "ffmpeg", "-v", "error", "-f", "lavfi", "-i", "testsrc=size=720x1280:rate=15",
            "-t", "3", "-c:v", "libx264", "-pix_fmt", "yuv420p", str(video),
        ],
        check=True,
    )
    target = tmp_path / "t.jpg"
    assert extract_thumbnail(video, target, duration_ms=3000)
    assert target.read_bytes()[:3] == b"\xff\xd8\xff"
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=width,height", "-of", "csv=p=0",
         str(target)],
        capture_output=True, text=True, check=True,
    )
    width, height = (int(n) for n in probe.stdout.strip().split(","))
    assert (width, height) == (640, 1138)

    assert not extract_thumbnail(tmp_path / "missing.mp4", tmp_path / "x.jpg", duration_ms=None)


def test_make_thumbnail_uploads_next_to_the_video_and_never_raises(tmp_path, monkeypatch) -> None:
    source = tmp_path / "artifact.mp4"
    source.write_bytes(b"video")
    storage = _Storage()

    def fake_extract(src, target, *, duration_ms):
        target.write_bytes(JPEG)
        return True

    monkeypatch.setattr(worker, "extract_thumbnail", fake_extract)
    key = asyncio.run(
        worker._make_thumbnail(storage, source, "users/u/recordings/r/a.mp4", duration_ms=5000)
    )
    assert key == "users/u/recordings/r/a.jpg"
    assert storage.uploads[key] == (JPEG, "image/jpeg")
    assert not source.with_suffix(".thumb.jpg").exists()

    monkeypatch.setattr(worker, "extract_thumbnail", lambda *a, **k: False)
    assert asyncio.run(worker._make_thumbnail(storage, source, "k.mp4", duration_ms=None)) is None

    class Broken(_Storage):
        def upload_file(self, *a, **k):
            raise RuntimeError("R2 down")

    monkeypatch.setattr(worker, "extract_thumbnail", fake_extract)
    assert asyncio.run(worker._make_thumbnail(Broken(), source, "k.mp4", duration_ms=None)) is None


def test_thumbnail_links_are_stable_within_the_hour() -> None:
    assert stable_expiry(7200) == stable_expiry(7200 + 3599) == 4 * 3600
    assert stable_expiry(7200 + 3600) == 5 * 3600
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        media_base_url="https://savestream-media.example.workers.dev",
        media_signing_secret="s" * 40,
    )
    first = signed_media_url(settings, "users/u/r/a.jpg", expires_at=stable_expiry(7300))
    second = signed_media_url(settings, "users/u/r/a.jpg", expires_at=stable_expiry(9000))
    assert first == second and "e=14400" in first


def test_recording_response_carries_the_thumbnail_url(tmp_path) -> None:
    settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'thumbs.db'}")

    async def run() -> tuple[str | None, str | None]:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = _seed_user(session, "thumbs@example.com")
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id)
                principal = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))
                service = RecordingService(session, settings)
                recording = await service.create(
                    principal,
                    CreateRecordingRequest(source=Source(type="username", value="maya")),
                    idempotency_key=str(uuid.uuid4()),
                )
                request = SimpleNamespace(
                    app=SimpleNamespace(state=SimpleNamespace(minio=_Storage(), settings=settings))
                )
                before = await get_recording(
                    str(recording.id), request, principal=principal, service=service  # type: ignore[arg-type]
                )
                key = f"users/{user.id}/recordings/{recording.id}/a.mp4"
                session.add(
                    RecordingArtifact(
                        recording_id=recording.id,
                        storage_key=key,
                        container="mp4",
                        size_bytes=1,
                        checksum_sha256="a" * 64,
                        thumbnail_key=thumbnail_key_for(key),
                    )
                )
                await session.commit()
                after = await get_recording(
                    str(recording.id), request, principal=principal, service=service  # type: ignore[arg-type]
                )
                return before.thumbnail_url, after.thumbnail_url
        finally:
            await database.close()

    before, after = asyncio.run(run())
    assert before is None
    assert after is not None and after.endswith(".jpg?e=1&s=x")


def test_backfill_makes_missing_thumbnails_only_with_apply(tmp_path) -> None:
    from tests.test_backfill_media import _seed_completed, _settings

    settings = _settings(tmp_path)
    key = "users/u/recordings/r/old.mp4"
    asyncio.run(_seed_completed(settings, artifact_key=key))
    storage = _Storage()
    seen: list[tuple[str, int | None]] = []

    def fake_extract(url, target, *, duration_ms):
        seen.append((url, duration_ms))
        target.write_bytes(JPEG)
        return True

    dry = asyncio.run(
        backfill_thumbnails(settings, apply=False, storage=storage, extract=fake_extract)  # type: ignore[arg-type]
    )
    assert [row.applied for row in dry] == [False] and not seen and not storage.uploads

    applied = asyncio.run(
        backfill_thumbnails(settings, apply=True, storage=storage, extract=fake_extract)  # type: ignore[arg-type]
    )
    assert [row.applied for row in applied] == [True]
    assert seen == [(f"https://r2.example/{key}?sig=1", None)]
    assert storage.uploads["users/u/recordings/r/old.jpg"] == (JPEG, "image/jpeg")

    async def stored() -> str | None:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                return await session.scalar(select(RecordingArtifact.thumbnail_key))
        finally:
            await database.close()

    assert asyncio.run(stored()) == "users/u/recordings/r/old.jpg"
    # Nothing left to do on a second run.
    assert asyncio.run(
        backfill_thumbnails(settings, apply=True, storage=storage, extract=fake_extract)  # type: ignore[arg-type]
    ) == []
