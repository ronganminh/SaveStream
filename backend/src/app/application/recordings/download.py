from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

from app.infrastructure.db.recording_models import Recording

_UNSAFE = re.compile(r"[^A-Za-z0-9._-]+")


def download_filename(recording: Recording, *, tz_offset_minutes: int = 0) -> str:
    """Readable file name for a recording download, e.g. `p.c.dat25_2026-10-14_2106.mp4`.

    The time is when the recording started, shifted by the viewer's UTC
    offset so it matches the clock they saw. Only `[A-Za-z0-9._-]` are kept,
    so the name is safe inside a Content-Disposition header.
    """
    creator = (recording.resolved_username or recording.source_value or "").lstrip("@")
    creator = _UNSAFE.sub("_", creator).strip("._-")[:64] or "recording"
    started = recording.started_at or recording.created_at or datetime.now(timezone.utc)
    if started.tzinfo is None:
        started = started.replace(tzinfo=timezone.utc)
    local = started.astimezone(timezone(timedelta(minutes=tz_offset_minutes)))
    return f"{creator}_{local:%Y-%m-%d_%H%M}.mp4"


def attachment_disposition(filename: str) -> str:
    return f'attachment; filename="{filename}"'
