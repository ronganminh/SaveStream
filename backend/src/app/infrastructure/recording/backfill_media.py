"""Backfill the real media length and frame size of artifacts recorded before
ffprobe was used (#177).

    python -m app.infrastructure.recording.backfill_media [--apply] [--limit N]

Without --apply it only prints what it would change. For each live video
artifact with no probed duration or frame size it runs ffprobe over a
short-lived signed URL (ffprobe reads only the parts it needs), then stores
`duration_ms`, `width` and `height` on the artifact and the probed length as
the recording's displayed `duration_seconds`.

Credits are never touched: the charge was settled when the recording finished
(`actual_cost` and the credit ledger), and nothing recomputes it from
`duration_seconds`.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
import time
from dataclasses import dataclass
from typing import Callable

from sqlalchemy import or_, select

from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.db.session import Database
from app.infrastructure.recording.media_probe import MediaInfo, probe_media
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import AppSettings, get_app_settings

logger = logging.getLogger("savestream.recording.backfill_media")

PROBE_ATTEMPTS = 3


@dataclass(frozen=True, slots=True)
class BackfillRow:
    artifact_id: str
    recording_id: str
    old_duration_seconds: int
    new_duration_seconds: int | None
    width: int | None
    height: int | None
    applied: bool


def _probe_with_retry(url: str, probe: Callable[[str], MediaInfo]) -> MediaInfo:
    info = MediaInfo()
    for attempt in range(1, PROBE_ATTEMPTS + 1):
        info = probe(url)
        if info.duration_ms is not None:
            return info
        if attempt < PROBE_ATTEMPTS:
            time.sleep(2 * attempt)
    return info


async def backfill_artifact_media(
    settings: AppSettings,
    *,
    apply: bool,
    limit: int = 500,
    storage: MinioStorageClient | None = None,
    probe: Callable[[str], MediaInfo] = probe_media,
) -> list[BackfillRow]:
    storage = storage or MinioStorageClient(settings)
    database = Database(settings.database_url)
    rows: list[BackfillRow] = []
    try:
        async with database.session() as session:
            pending = (
                await session.execute(
                    select(RecordingArtifact, Recording)
                    .join(Recording, Recording.id == RecordingArtifact.recording_id)
                    .where(
                        RecordingArtifact.deleted_at.is_(None),
                        RecordingArtifact.kind == "video",
                        or_(
                            RecordingArtifact.duration_ms.is_(None),
                            RecordingArtifact.width.is_(None),
                            RecordingArtifact.height.is_(None),
                        ),
                    )
                    .order_by(RecordingArtifact.created_at)
                    .limit(limit)
                )
            ).all()
            for artifact, recording in pending:
                url = await asyncio.to_thread(storage.presigned_get_url, artifact.storage_key)
                info = await asyncio.to_thread(_probe_with_retry, url, probe)
                old_duration = recording.duration_seconds
                usable = info.duration_ms is not None
                if apply and usable:
                    artifact.duration_ms = info.duration_ms
                    artifact.width = info.width
                    artifact.height = info.height
                    # Display length only; actual_cost and the ledger stay as settled.
                    recording.duration_seconds = info.duration_seconds or old_duration
                    await session.commit()
                rows.append(
                    BackfillRow(
                        artifact_id=str(artifact.id),
                        recording_id=str(recording.id),
                        old_duration_seconds=old_duration,
                        new_duration_seconds=info.duration_seconds,
                        width=info.width,
                        height=info.height,
                        applied=apply and usable,
                    )
                )
    finally:
        await database.close()
    return rows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--apply", action="store_true", help="write the probed values")
    parser.add_argument("--limit", type=int, default=500)
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO)

    rows = asyncio.run(
        backfill_artifact_media(get_app_settings(), apply=args.apply, limit=args.limit)
    )
    mode = "APPLY" if args.apply else "DRY RUN"
    print(f"{mode}: {len(rows)} artifact(s) without probed media info")
    for row in rows:
        size = f"{row.width}x{row.height}" if row.width and row.height else "-"
        status = "updated" if row.applied else ("unreadable" if row.new_duration_seconds is None else "would update")
        print(
            f"{row.recording_id} artifact={row.artifact_id} "
            f"duration {row.old_duration_seconds}s -> {row.new_duration_seconds}s "
            f"size {size} [{status}]"
        )
    failed = sum(1 for row in rows if row.new_duration_seconds is None)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
