from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class MediaInfo:
    duration_ms: int | None = None
    width: int | None = None
    height: int | None = None

    @property
    def duration_seconds(self) -> int | None:
        """Whole seconds for display and billing; at least 1 for a non-empty file."""
        if self.duration_ms is None:
            return None
        return max(1, round(self.duration_ms / 1000))


def _positive_int(value: object) -> int | None:
    try:
        number = int(value)  # type: ignore[call-overload]
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None


def _rotation(stream: dict) -> int:
    """Display rotation in degrees (0/90/180/270) from side data or tags."""
    values: list[object] = [stream.get("tags", {}).get("rotate")]
    values += [item.get("rotation") for item in stream.get("side_data_list", [])]
    for value in values:
        try:
            return int(float(value)) % 360  # type: ignore[arg-type]
        except (TypeError, ValueError):
            continue
    return 0


def probe_media(path: Path, *, timeout_seconds: float = 60) -> MediaInfo:
    """Read the real duration and frame size of a finished file with ffprobe.

    The job's wall clock includes connection and finalize time, so it is
    longer than the media itself. Returns an empty MediaInfo when ffprobe is
    missing or the file cannot be read; callers keep their fallback values.
    """
    try:
        completed = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-print_format",
                "json",
                "-show_format",
                "-show_streams",
                str(path),
            ],
            capture_output=True,
            check=True,
            timeout=timeout_seconds,
        )
        data = json.loads(completed.stdout or b"{}")
    except (OSError, subprocess.SubprocessError, ValueError):
        return MediaInfo()

    duration_ms: int | None = None
    try:
        seconds = float(data.get("format", {}).get("duration"))
        if seconds > 0:
            duration_ms = round(seconds * 1000)
    except (TypeError, ValueError):
        pass

    width = height = None
    for stream in data.get("streams", []):
        if stream.get("codec_type") == "video":
            width = _positive_int(stream.get("width"))
            height = _positive_int(stream.get("height"))
            if _rotation(stream) in (90, 270) and width and height:
                width, height = height, width
            if duration_ms is None:
                try:
                    seconds = float(stream.get("duration"))
                    duration_ms = round(seconds * 1000) if seconds > 0 else None
                except (TypeError, ValueError):
                    pass
            break
    return MediaInfo(duration_ms=duration_ms, width=width, height=height)
