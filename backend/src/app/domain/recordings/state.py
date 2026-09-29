from __future__ import annotations

from dataclasses import dataclass
from enum import Enum

from app.domain.common.errors import ApplicationError


class RecordingStatus(str, Enum):
    QUEUED = "queued"
    RESOLVING = "resolving"
    WAITING_LIVE = "waiting_live"
    RECORDING = "recording"
    PROCESSING = "processing"
    UPLOADING = "uploading"
    COMPLETED = "completed"
    FAILED = "failed"
    STOP_REQUESTED = "stop_requested"
    STOPPED = "stopped"


ACTIVE_RECORDING_STATUSES = frozenset(
    {
        RecordingStatus.QUEUED,
        RecordingStatus.RESOLVING,
        RecordingStatus.WAITING_LIVE,
        RecordingStatus.RECORDING,
        RecordingStatus.PROCESSING,
        RecordingStatus.UPLOADING,
        RecordingStatus.STOP_REQUESTED,
    }
)
TERMINAL_RECORDING_STATUSES = frozenset(
    {
        RecordingStatus.COMPLETED,
        RecordingStatus.FAILED,
        RecordingStatus.STOPPED,
    }
)

_ALLOWED: dict[RecordingStatus, frozenset[RecordingStatus]] = {
    RecordingStatus.QUEUED: frozenset(
        {RecordingStatus.RESOLVING, RecordingStatus.STOP_REQUESTED, RecordingStatus.FAILED}
    ),
    RecordingStatus.RESOLVING: frozenset(
        {
            RecordingStatus.WAITING_LIVE,
            RecordingStatus.RECORDING,
            RecordingStatus.FAILED,
        }
    ),
    RecordingStatus.WAITING_LIVE: frozenset(
        {
            RecordingStatus.RECORDING,
            RecordingStatus.STOP_REQUESTED,
            RecordingStatus.FAILED,
        }
    ),
    RecordingStatus.RECORDING: frozenset(
        {
            RecordingStatus.PROCESSING,
            RecordingStatus.STOP_REQUESTED,
            RecordingStatus.FAILED,
        }
    ),
    RecordingStatus.PROCESSING: frozenset(
        {RecordingStatus.UPLOADING, RecordingStatus.FAILED}
    ),
    RecordingStatus.UPLOADING: frozenset(
        {RecordingStatus.COMPLETED, RecordingStatus.STOPPED, RecordingStatus.FAILED}
    ),
    RecordingStatus.STOP_REQUESTED: frozenset(
        {RecordingStatus.STOPPED, RecordingStatus.PROCESSING, RecordingStatus.FAILED}
    ),
    RecordingStatus.COMPLETED: frozenset(),
    RecordingStatus.FAILED: frozenset(),
    RecordingStatus.STOPPED: frozenset(),
}


@dataclass(frozen=True, slots=True)
class RecordingActions:
    can_stop: bool
    can_retry: bool
    can_delete: bool


def actions_for_status(status: RecordingStatus) -> RecordingActions:
    return RecordingActions(
        can_stop=status
        in {
            RecordingStatus.QUEUED,
            RecordingStatus.WAITING_LIVE,
            RecordingStatus.RECORDING,
        },
        can_retry=status is RecordingStatus.FAILED,
        can_delete=status in TERMINAL_RECORDING_STATUSES,
    )


def transition(current: RecordingStatus, target: RecordingStatus) -> RecordingStatus:
    if target == current:
        return current
    if target not in _ALLOWED[current]:
        raise ApplicationError(
            "VALIDATION_ERROR",
            f"Recording transition {current.value} -> {target.value} is not allowed",
            status_code=409,
        )
    return target
