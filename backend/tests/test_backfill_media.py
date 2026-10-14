"""QA 2026-10-14: f9d4ebc5 (recorded before #177) showed 1h 37m and no
resolution; the file is 5957 s. The backfill stores the probed values without
touching credits."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from sqlalchemy import func, select

from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.session import Database
from app.infrastructure.recording.backfill_media import backfill_artifact_media
from app.infrastructure.recording.media_probe import MediaInfo
from tests.identity_helpers import identity_settings
from tests.test_recording_upload_retry_and_stuck import _seed_recording


class _Storage:
    def presigned_get_url(self, key: str, *, content_disposition=None) -> str:
        return f"https://r2.example/{key}?sig=1"


def _settings(tmp_path):
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'backfill.db'}"),
        recording_temp_dir=str(tmp_path / "rec"),
    )


async def _seed_completed(settings, *, artifact_key: str) -> uuid.UUID:
    recording_id = await _seed_recording(settings)
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            recording = await session.get(Recording, recording_id)
            assert recording is not None
            recording.status = "completed"
            recording.duration_seconds = 5822  # wall clock of the old worker
            recording.actual_cost = 97
            session.add(
                RecordingArtifact(
                    recording_id=recording_id,
                    kind="video",
                    container="mp4",
                    storage_key=artifact_key,
                    size_bytes=803_000_000,
                    checksum_sha256="0" * 64,
                )
            )
            await session.commit()
    finally:
        await database.close()
    return recording_id


async def _state(settings, recording_id):
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            recording = await session.get(Recording, recording_id)
            artifact = await session.scalar(
                select(RecordingArtifact).where(RecordingArtifact.recording_id == recording_id)
            )
            ledger = (
                await session.execute(
                    select(func.count(), func.coalesce(func.sum(CreditLedgerEntry.amount), 0))
                )
            ).one()
            assert recording is not None and artifact is not None
            return recording, artifact, tuple(ledger)
    finally:
        await database.close()


def test_dry_run_changes_nothing_and_apply_stores_probed_values(tmp_path) -> None:
    settings = _settings(tmp_path)
    recording_id = asyncio.run(_seed_completed(settings, artifact_key="users/a/long.mp4"))
    _, _, ledger_before = asyncio.run(_state(settings, recording_id))
    probed: list[str] = []

    def probe(url: str) -> MediaInfo:
        probed.append(url)
        return MediaInfo(duration_ms=5_957_300, width=720, height=1280)

    rows = asyncio.run(
        backfill_artifact_media(settings, apply=False, storage=_Storage(), probe=probe)
    )
    assert [(r.old_duration_seconds, r.new_duration_seconds, r.applied) for r in rows] == [
        (5822, 5957, False)
    ]
    recording, artifact, _ = asyncio.run(_state(settings, recording_id))
    assert recording.duration_seconds == 5822 and artifact.duration_ms is None

    rows = asyncio.run(
        backfill_artifact_media(settings, apply=True, storage=_Storage(), probe=probe)
    )
    assert rows[0].applied
    assert probed[-1] == "https://r2.example/users/a/long.mp4?sig=1"
    recording, artifact, ledger_after = asyncio.run(_state(settings, recording_id))
    assert (artifact.duration_ms, artifact.width, artifact.height) == (5_957_300, 720, 1280)
    assert recording.duration_seconds == 5957
    # Credits stay exactly as settled.
    assert recording.actual_cost == 97
    assert ledger_after == ledger_before

    # Nothing left to do on a second run.
    assert asyncio.run(
        backfill_artifact_media(settings, apply=True, storage=_Storage(), probe=probe)
    ) == []


def test_unreadable_file_is_reported_and_left_unchanged(tmp_path, monkeypatch) -> None:
    import app.infrastructure.recording.backfill_media as backfill

    monkeypatch.setattr(backfill.time, "sleep", lambda _s: None)
    settings = _settings(tmp_path)
    recording_id = asyncio.run(_seed_completed(settings, artifact_key="users/a/broken.mp4"))
    calls: list[str] = []

    def probe(url: str) -> MediaInfo:
        calls.append(url)
        return MediaInfo()

    rows = asyncio.run(
        backfill_artifact_media(settings, apply=True, storage=_Storage(), probe=probe)
    )
    assert len(calls) == backfill.PROBE_ATTEMPTS
    assert rows[0].new_duration_seconds is None and not rows[0].applied
    recording, artifact, _ = asyncio.run(_state(settings, recording_id))
    assert recording.duration_seconds == 5822
    assert artifact.duration_ms is None
