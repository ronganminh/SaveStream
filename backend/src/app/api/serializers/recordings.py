from __future__ import annotations

from app.api.schemas.recordings import (
    ArtifactResponse,
    Creator,
    RecordingActions,
    RecordingError,
    RecordingResponse,
    Source,
)
from app.domain.recordings.state import RecordingStatus, actions_for_status
from app.infrastructure.db.recording_models import Recording, RecordingArtifact


def recording_response(recording: Recording) -> RecordingResponse:
    status = RecordingStatus(recording.status)
    actions = actions_for_status(status)
    creator = None
    if recording.resolved_username:
        creator = Creator(
            username=recording.resolved_username,
            display_name=recording.resolved_username,
            avatar_url=None,
        )
    error = None
    if recording.error_code and recording.error_message:
        error = RecordingError(
            code=recording.error_code,
            message=recording.error_message,
            retryable=bool(recording.error_retryable),
        )
    return RecordingResponse(
        id=str(recording.id),
        source=Source(type=recording.source_type, value=recording.source_value),
        creator=creator,
        status=status.value,
        started_at=recording.started_at,
        ended_at=recording.ended_at,
        duration_seconds=recording.duration_seconds,
        bytes_recorded=recording.bytes_recorded,
        estimated_max_cost=recording.estimated_max_cost,
        actual_cost=recording.actual_cost,
        credit_reservation_id=recording.credit_reservation_id,
        actions=RecordingActions(
            can_stop=actions.can_stop,
            can_retry=actions.can_retry,
            can_delete=actions.can_delete,
        ),
        error=error,
        created_at=recording.created_at,
        updated_at=recording.updated_at,
    )


def artifact_response(artifact: RecordingArtifact) -> ArtifactResponse:
    return ArtifactResponse(
        id=str(artifact.id),
        recording_id=str(artifact.recording_id),
        kind="video",
        container="mp4",
        size_bytes=artifact.size_bytes,
        checksum_sha256=artifact.checksum_sha256,
        created_at=artifact.created_at,
    )
