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


def probe_media(path: Path | str, *, timeout_seconds: float = 60) -> MediaInfo:
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
    rotation = 0
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
            rotation = _rotation(stream)
            break
    if width and height and duration_ms:
        # TikTok switches resolution mid-stream (adaptive bitrate); the stream
        # header only describes the start. Report the largest frame size seen.
        for sample_width, sample_height in _sample_frame_sizes(
            path, duration_ms / 1000, rotation, timeout_seconds=timeout_seconds
        ):
            if sample_width * sample_height > width * height:
                width, height = sample_width, sample_height
    return MediaInfo(duration_ms=duration_ms, width=width, height=height)


FRAME_SAMPLES = 24
# Packets read after each seek; enough to reach the next keyframe even when
# the container cannot seek exactly onto one.
PACKETS_PER_SAMPLE = 20


def _sample_frame_sizes(
    path: Path | str,
    duration_seconds: float,
    rotation: int,
    *,
    timeout_seconds: float,
) -> list[tuple[int, int]]:
    """Decoded size of one keyframe at evenly spaced points of the file.

    Seeks rather than reading everything, so it is cheap over a signed URL.
    """
    points = [duration_seconds * i / FRAME_SAMPLES for i in range(FRAME_SAMPLES)]
    intervals = ",".join(f"{point:.3f}%+#{PACKETS_PER_SAMPLE}" for point in points)
    try:
        completed = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-skip_frame",
                "nokey",
                "-read_intervals",
                intervals,
                "-show_entries",
                "frame=width,height",
                "-print_format",
                "json",
                str(path),
            ],
            capture_output=True,
            check=True,
            timeout=timeout_seconds * 3,
        )
        frames = json.loads(completed.stdout or b"{}").get("frames", [])
    except (OSError, subprocess.SubprocessError, ValueError):
        return []
    sizes: list[tuple[int, int]] = []
    for frame in frames:
        width = _positive_int(frame.get("width"))
        height = _positive_int(frame.get("height"))
        if width and height:
            sizes.append((height, width) if rotation in (90, 270) else (width, height))
    return sizes


THUMBNAIL_WIDTH = 640


def thumbnail_key_for(storage_key: str) -> str:
    """`.../<artifact>.mp4` -> `.../<artifact>.jpg` (same folder as the video)."""
    return storage_key.rsplit(".", 1)[0] + ".jpg"


def thumbnail_offset_seconds(duration_ms: int | None) -> float:
    """Where to grab the frame: a little in, past black or loading frames at
    the very start, but never past the end of a short clip."""
    if not duration_ms:
        return 1.0
    seconds = duration_ms / 1000
    return round(min(10.0, max(0.0, seconds / 3)), 3)


def extract_thumbnail(
    source: Path | str,
    target: Path,
    *,
    duration_ms: int | None,
    timeout_seconds: float = 60,
) -> bool:
    """Write one JPEG frame (640 px wide) of `source` to `target`.

    `source` may be a local file or a signed URL; ffmpeg seeks before
    decoding, so only a small part of a remote file is read. Returns False
    when ffmpeg is missing or no frame could be decoded; callers keep the
    gradient placeholder.
    """
    try:
        subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-ss",
                str(thumbnail_offset_seconds(duration_ms)),
                "-i",
                str(source),
                "-frames:v",
                "1",
                "-vf",
                f"scale='min({THUMBNAIL_WIDTH},iw)':-2",
                "-q:v",
                "4",
                str(target),
            ],
            capture_output=True,
            check=True,
            timeout=timeout_seconds,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return target.exists() and target.stat().st_size > 0
