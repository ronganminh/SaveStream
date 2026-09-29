from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import (
    RecordingStatus,
    actions_for_status,
    transition,
)


def test_recording_state_machine_and_actions_are_frozen():
    assert transition(RecordingStatus.QUEUED, RecordingStatus.RESOLVING) is RecordingStatus.RESOLVING
    assert transition(RecordingStatus.RECORDING, RecordingStatus.STOP_REQUESTED) is RecordingStatus.STOP_REQUESTED
    assert transition(RecordingStatus.STOP_REQUESTED, RecordingStatus.STOPPED) is RecordingStatus.STOPPED

    assert actions_for_status(RecordingStatus.RECORDING).can_stop is True
    assert actions_for_status(RecordingStatus.FAILED).can_retry is True
    assert actions_for_status(RecordingStatus.COMPLETED).can_delete is True


def test_invalid_recording_transition_is_rejected():
    try:
        transition(RecordingStatus.COMPLETED, RecordingStatus.RECORDING)
    except ApplicationError as exc:
        assert exc.status_code == 409
        assert exc.code == "VALIDATION_ERROR"
    else:
        raise AssertionError("invalid transition should fail")
