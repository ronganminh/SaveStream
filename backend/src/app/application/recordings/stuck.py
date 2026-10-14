from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.recordings.service import utcnow
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.recording_models import Recording, RecordingEvent

FINALIZING_STATUSES = (RecordingStatus.PROCESSING.value, RecordingStatus.UPLOADING.value)
FINALIZING_EVENTS = ("recording.processing", "recording.uploading")


@dataclass(frozen=True, slots=True)
class StuckUpload:
    recording: Recording
    since: datetime


async def find_stuck_uploads(
    session: AsyncSession,
    *,
    older_than_seconds: int,
    limit: int = 50,
) -> list[StuckUpload]:
    """Recordings still processing/uploading `older_than_seconds` after the
    capture ended (measured from their processing/uploading event, not from
    `updated_at`, which the worker heartbeat keeps refreshing)."""
    since = (
        select(
            RecordingEvent.recording_id.label("recording_id"),
            func.max(RecordingEvent.created_at).label("since"),
        )
        .where(RecordingEvent.event_type.in_(FINALIZING_EVENTS))
        .group_by(RecordingEvent.recording_id)
        .subquery()
    )
    cutoff = utcnow() - timedelta(seconds=older_than_seconds)
    rows = (
        await session.execute(
            select(Recording, since.c.since)
            .join(since, since.c.recording_id == Recording.id)
            .where(
                Recording.deleted_at.is_(None),
                Recording.status.in_(FINALIZING_STATUSES),
                since.c.since < cutoff,
            )
            .order_by(since.c.since)
            .limit(limit)
        )
    ).all()
    return [StuckUpload(recording=row[0], since=row[1]) for row in rows]
