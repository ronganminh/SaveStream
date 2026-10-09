from __future__ import annotations

import uuid

from app.infrastructure.db.recording_models import Recording
from app.infrastructure.recording.worker import _ensure_stop_requested_transition


def _recording(status: str) -> Recording:
    return Recording(
        id=uuid.uuid4(),
        user_id=uuid.uuid4(),
        source_type="username",
        source_value="creator",
        status=status,
        duration_seconds=0,
        bytes_recorded=0,
        estimated_max_cost=0,
    )


def test_running_capture_is_normalized_before_stopped_transition() -> None:
    recording = _recording("recording")

    assert _ensure_stop_requested_transition(recording) is True
    assert recording.status == "stop_requested"


def test_existing_stop_request_is_not_duplicated() -> None:
    recording = _recording("stop_requested")

    assert _ensure_stop_requested_transition(recording) is False
    assert recording.status == "stop_requested"
