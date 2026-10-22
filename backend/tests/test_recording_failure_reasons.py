"""Friendly failure reasons on recording responses (QA: raw error.message only)."""

from __future__ import annotations

import asyncio
import re
import uuid
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from app.api.dependencies import get_current_principal
from app.api.serializers.recordings import recording_response
from app.application.recordings.failure_reasons import (
    FAILURE_REASONS,
    MISSED_NO_CLOUD_SLOT_REASON,
    NOT_CHARGED_NOTE,
    UNKNOWN_FAILURE_REASON,
    explain_recording_failure,
    failure_reason_for_code,
)
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.main import create_app
from tests.identity_helpers import identity_settings

# Every code RecordingStateStore.fail is called with today.
PRODUCED_CODES = ("STREAM_OFFLINE", "STREAM_UNAVAILABLE", "SERVICE_UNAVAILABLE")

# Messages the recorder writes, with the reason each should map to.
PRODUCED_MESSAGES = {
    ("STREAM_OFFLINE", "The source is currently offline"): (
        "The LIVE ended before recording could start."
    ),
    ("STREAM_UNAVAILABLE", "Unable to resolve stream"): (
        "We couldn't connect to this LIVE's video stream."
    ),
    ("STREAM_UNAVAILABLE", "ffmpeg exited with status 1: /tmp/rec/abc.flv"): (
        "We couldn't connect to this LIVE's video stream."
    ),
    ("STREAM_UNAVAILABLE", "Recording produced no valid media"): (
        "The LIVE ended before any video could be saved."
    ),
    (
        "SERVICE_UNAVAILABLE",
        "Artifact upload failed: Connection refused https://minio.internal:9000/bucket",
    ): "The LIVE was recorded, but we couldn't save the video file.",
    ("SERVICE_UNAVAILABLE", "Recording worker retry limit exceeded"): (
        "Our recorder couldn't finish this recording after several tries."
    ),
}

_INTERNALS = re.compile(r"https?://|/tmp|\.py\b|Traceback|Exception|[A-Z]{2,}_[A-Z]")


def _all_strings() -> list[str]:
    reasons = [*FAILURE_REASONS.values(), MISSED_NO_CLOUD_SLOT_REASON, UNKNOWN_FAILURE_REASON]
    reasons += [failure_reason_for_code(code, msg) for code, msg in PRODUCED_MESSAGES]
    strings: list[str] = []
    for item in reasons:
        strings.append(item.reason)
        if item.guidance:
            strings.append(item.guidance)
    return strings


def test_every_produced_code_has_a_specific_reason() -> None:
    assert set(PRODUCED_CODES) <= set(FAILURE_REASONS)
    for code in PRODUCED_CODES:
        reason = failure_reason_for_code(code)
        assert reason != UNKNOWN_FAILURE_REASON
        assert reason.reason.endswith(".")
        assert reason.guidance


@pytest.mark.parametrize(("key", "expected"), list(PRODUCED_MESSAGES.items()))
def test_produced_messages_map_to_friendly_reasons(
    key: tuple[str, str], expected: str
) -> None:
    code, message = key
    assert failure_reason_for_code(code, message).reason == expected


def test_code_lookup_ignores_case_and_whitespace() -> None:
    assert failure_reason_for_code(" stream_offline ") == FAILURE_REASONS["STREAM_OFFLINE"]


@pytest.mark.parametrize("code", [None, "", "SOMETHING_NEW", "INTERNAL_ERROR"])
def test_unknown_codes_fall_back_to_generic_reason(code: str | None) -> None:
    reason = failure_reason_for_code(code, "Traceback (most recent call last): ...")
    assert reason == UNKNOWN_FAILURE_REASON
    assert reason.reason == "Something went wrong while saving this recording."
    assert reason.guidance is not None and "report a problem" in reason.guidance


def test_message_variant_only_applies_to_its_own_code() -> None:
    assert (
        failure_reason_for_code("STREAM_OFFLINE", "Artifact upload failed: x")
        == FAILURE_REASONS["STREAM_OFFLINE"]
    )


def test_user_facing_strings_never_contain_internals() -> None:
    for text in _all_strings():
        assert not _INTERNALS.search(text), text
        assert len(text) <= 140, text


@pytest.mark.parametrize(
    "status",
    [s for s in RecordingStatus if s not in {RecordingStatus.FAILED, RecordingStatus.MISSED_NO_CLOUD_SLOT}],
)
def test_non_failed_statuses_have_no_explanation(status: RecordingStatus) -> None:
    assert (
        explain_recording_failure(
            status, error_code="STREAM_OFFLINE", error_message="x", charged=False
        )
        is None
    )


def test_missed_and_charge_note() -> None:
    missed = explain_recording_failure(
        RecordingStatus.MISSED_NO_CLOUD_SLOT,
        error_code=None,
        error_message=None,
        charged=False,
    )
    assert missed is not None
    assert missed.reason == MISSED_NO_CLOUD_SLOT_REASON.reason
    assert missed.guidance is not None and missed.guidance.endswith(NOT_CHARGED_NOTE)

    charged = explain_recording_failure(
        RecordingStatus.FAILED,
        error_code="STREAM_OFFLINE",
        error_message=None,
        charged=True,
    )
    assert charged == FAILURE_REASONS["STREAM_OFFLINE"]


def _recording(**overrides: object) -> Recording:
    now = datetime(2026, 10, 22, 12, 0, tzinfo=UTC)
    values: dict[str, object] = {
        "id": uuid.uuid4(),
        "user_id": uuid.uuid4(),
        "source_type": "username",
        "source_value": "creator",
        "status": "completed",
        "duration_seconds": 120,
        "bytes_recorded": 1000,
        "estimated_max_cost": 2,
        "actual_cost": 2,
        "created_at": now,
        "updated_at": now,
    }
    values.update(overrides)
    return Recording(**values)


def test_serializer_failed_recording_has_reason_and_keeps_error() -> None:
    raw = "Artifact upload failed: Connection refused https://minio.internal:9000/b"
    response = recording_response(
        _recording(
            status="failed",
            actual_cost=0,
            error_code="SERVICE_UNAVAILABLE",
            error_message=raw,
            error_retryable=True,
        )
    )
    assert response.error is not None
    assert response.error.code == "SERVICE_UNAVAILABLE"
    assert response.error.message == raw
    assert response.failure_reason == (
        "The LIVE was recorded, but we couldn't save the video file."
    )
    assert response.failure_guidance == (
        "This was a problem on our side. Contact support if this keeps happening. "
        "You weren't charged for this recording."
    )
    assert response.minutes_charged == 0


def test_serializer_completed_recording_has_no_reason() -> None:
    response = recording_response(_recording())
    assert response.error is None
    assert response.failure_reason is None
    assert response.failure_guidance is None
    dumped = response.model_dump(mode="json")
    assert dumped["failure_reason"] is None
    assert dumped["failure_guidance"] is None


def test_serializer_failed_without_error_row_uses_generic_reason() -> None:
    response = recording_response(_recording(status="failed", actual_cost=0))
    assert response.error is None
    assert response.failure_reason == UNKNOWN_FAILURE_REASON.reason


def test_recordings_api_list_and_detail_expose_failure_reason(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'failure-reasons.db'}"
    settings = identity_settings(database_url)

    async def seed() -> tuple[AuthPrincipal, str, str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                owner = User(
                    email="failure-owner@example.com",
                    normalized_email="failure-owner@example.com",
                    role="user",
                    email_verified_at=datetime.now(UTC),
                )
                session.add(owner)
                await session.commit()
                await session.refresh(owner)
                failed = Recording(
                    user_id=owner.id,
                    source_type="username",
                    source_value="short-live",
                    status="failed",
                    actual_cost=0,
                    error_code="STREAM_OFFLINE",
                    error_message="The source is currently offline",
                    error_retryable=False,
                )
                completed = Recording(
                    user_id=owner.id,
                    source_type="username",
                    source_value="long-live",
                    status="completed",
                    actual_cost=3,
                    duration_seconds=180,
                )
                session.add_all([failed, completed])
                await session.commit()
                return (
                    AuthPrincipal(owner.id, uuid.uuid4(), "user", scopes_for_role("user")),
                    str(failed.id),
                    str(completed.id),
                )
        finally:
            await database.close()

    principal, failed_id, completed_id = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: principal

    with TestClient(app, base_url="https://testserver") as client:
        listed = client.get("/v1/recordings")
        assert listed.status_code == 200, listed.text
        items = {item["id"]: item for item in listed.json()["items"]}

        detail = client.get(f"/v1/recordings/{failed_id}")
        assert detail.status_code == 200, detail.text

    for failed in (items[failed_id], detail.json()):
        assert failed["error"] == {
            "code": "STREAM_OFFLINE",
            "message": "The source is currently offline",
            "retryable": False,
        }
        assert failed["failure_reason"] == "The LIVE ended before recording could start."
        assert failed["failure_guidance"] == (
            "Very short LIVEs (under about a minute) may not be captured. "
            "You weren't charged for this recording."
        )
    assert items[completed_id]["failure_reason"] is None
    assert items[completed_id]["failure_guidance"] is None
