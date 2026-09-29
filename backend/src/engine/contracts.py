from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any


class StopReason(str, Enum):
    STREAM_ENDED = "stream_ended"
    DURATION_REACHED = "duration_reached"
    USER_REQUESTED = "user_requested"
    ERROR = "error"


@dataclass(frozen=True, slots=True)
class RecordingRequest:
    username: str
    room_id: str
    output_dir: Path
    duration_seconds: int | None = None
    min_valid_bytes: int = 100 * 1024
    buffer_size: int = 512 * 1024

    def __post_init__(self) -> None:
        if not self.username:
            raise ValueError("username is required")
        if not self.room_id:
            raise ValueError("room_id is required")
        if self.duration_seconds is not None and self.duration_seconds <= 0:
            raise ValueError("duration_seconds must be greater than zero")
        if self.min_valid_bytes < 0:
            raise ValueError("min_valid_bytes cannot be negative")
        if self.buffer_size <= 0:
            raise ValueError("buffer_size must be greater than zero")


@dataclass(frozen=True, slots=True)
class EngineEvent:
    kind: str
    message: str
    bytes_recorded: int = 0
    details: dict[str, Any] | None = None


@dataclass(frozen=True, slots=True)
class RecordingResult:
    source_path: Path
    artifact_path: Path | None
    bytes_recorded: int
    stop_reason: StopReason
    discarded: bool
    error: str | None = None
