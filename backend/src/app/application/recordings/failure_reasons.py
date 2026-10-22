"""Plain-English explanations for failed and missed recordings.

The ``error`` object on a recording keeps the raw technical message for
support and backward compatibility. Apps show these friendlier strings
instead. Every string here is fixed text: nothing from the raw error message
(URLs, paths, exception text) is ever copied into what users see.

Error codes the recorder can write today (``RecordingStateStore.fail``):

* ``STREAM_OFFLINE``      the creator was not LIVE when capture began.
* ``STREAM_UNAVAILABLE``  resolving or capturing the stream failed, or the
                          capture saved no usable video.
* ``SERVICE_UNAVAILABLE`` our side failed: upload to storage, or the worker
                          retry limit was hit.

``missed_no_cloud_slot`` recordings carry no error code; they get their own
explanation keyed on the status. Any other code falls back to a generic one.
"""

from __future__ import annotations

from dataclasses import dataclass

from app.domain.recordings.state import RecordingStatus

NOT_CHARGED_NOTE = "You weren't charged for this recording."


@dataclass(frozen=True, slots=True)
class FailureReason:
    reason: str
    guidance: str | None


_SHORT_LIVE = "Very short LIVEs (under about a minute) may not be captured."
_OUR_SIDE = "This was a problem on our side. Contact support if this keeps happening."

FAILURE_REASONS: dict[str, FailureReason] = {
    "STREAM_OFFLINE": FailureReason(
        reason="The LIVE ended before recording could start.",
        guidance=_SHORT_LIVE,
    ),
    "STREAM_UNAVAILABLE": FailureReason(
        reason="We couldn't connect to this LIVE's video stream.",
        guidance=(
            "This is usually temporary. Try again while the creator is still LIVE."
        ),
    ),
    "SERVICE_UNAVAILABLE": FailureReason(
        reason="Our recording service ran into a problem with this recording.",
        guidance=_OUR_SIDE,
    ),
}

# Finer explanations for one code, keyed on the fixed text our own recorder
# writes at the start of the message (see app/infrastructure/recording/worker.py
# and app/application/recordings/service.py). Matched by prefix only; the rest of the
# message is never shown.
_MESSAGE_VARIANTS: dict[str, tuple[tuple[str, FailureReason], ...]] = {
    "STREAM_UNAVAILABLE": (
        (
            "Recording produced no valid media",
            FailureReason(
                reason="The LIVE ended before any video could be saved.",
                guidance=_SHORT_LIVE,
            ),
        ),
    ),
    "SERVICE_UNAVAILABLE": (
        (
            "Artifact upload failed",
            FailureReason(
                reason="The LIVE was recorded, but we couldn't save the video file.",
                guidance=_OUR_SIDE,
            ),
        ),
        (
            "Recording worker retry limit exceeded",
            FailureReason(
                reason="Our recorder couldn't finish this recording after several tries.",
                guidance=_OUR_SIDE,
            ),
        ),
    ),
}

MISSED_NO_CLOUD_SLOT_REASON = FailureReason(
    reason="All your cloud recording slots were busy, so this LIVE wasn't recorded.",
    guidance=(
        "This happens when other recordings are already using every cloud "
        "slot you have at the same time."
    ),
)

UNKNOWN_FAILURE_REASON = FailureReason(
    reason="Something went wrong while saving this recording.",
    guidance="Please report a problem if this keeps happening.",
)

_EXPLAINED_STATUSES = frozenset(
    {RecordingStatus.FAILED, RecordingStatus.MISSED_NO_CLOUD_SLOT}
)


def failure_reason_for_code(
    code: str | None,
    message: str | None = None,
) -> FailureReason:
    """Friendly reason for a failure code; unknown or missing codes fall back."""

    if not code:
        return UNKNOWN_FAILURE_REASON
    normalized = code.strip().upper()
    if message:
        for prefix, variant in _MESSAGE_VARIANTS.get(normalized, ()):
            if message.startswith(prefix):
                return variant
    return FAILURE_REASONS.get(normalized, UNKNOWN_FAILURE_REASON)


def explain_recording_failure(
    status: RecordingStatus,
    *,
    error_code: str | None,
    error_message: str | None,
    charged: bool,
) -> FailureReason | None:
    """Reason and guidance for a failed or missed recording; None otherwise.

    Failed recordings release their credit reservation and settle at zero
    (``RecordingStateStore.fail``), and missed ones never reserve, so the
    not-charged note is added whenever nothing was charged.
    """

    if status not in _EXPLAINED_STATUSES:
        return None
    if status is RecordingStatus.MISSED_NO_CLOUD_SLOT:
        base = MISSED_NO_CLOUD_SLOT_REASON
    else:
        base = failure_reason_for_code(error_code, error_message)
    if charged:
        return base
    guidance = f"{base.guidance} {NOT_CHARGED_NOTE}" if base.guidance else NOT_CHARGED_NOTE
    return FailureReason(reason=base.reason, guidance=guidance)
