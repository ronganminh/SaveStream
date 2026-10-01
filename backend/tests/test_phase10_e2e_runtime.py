from __future__ import annotations

from dataclasses import replace

import pytest

from app.api.schemas.recordings import Source
from app.infrastructure.recording.runtime import (
    FakeHttpSourceResolver,
    HttpFakeLiveGateway,
    build_recording_runtime,
)
from tests.identity_helpers import identity_settings


def test_phase10_fake_runtime_is_explicit_and_nonproduction() -> None:
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        recording_source_backend="fake_http",
        e2e_stream_base_url="http://fake-stream:8090",
    )
    runtime = build_recording_runtime(settings)
    assert isinstance(runtime.resolver, FakeHttpSourceResolver)
    assert isinstance(runtime.gateway, HttpFakeLiveGateway)

    resolved = runtime.resolver.resolve(
        Source(type="room_id", value="e2e-room")
    )
    assert resolved.room_id == "e2e-room"
    assert resolved.username == "e2e_e2e-room"

    production = replace(settings, environment="production")
    with pytest.raises(RuntimeError, match="disabled in production"):
        build_recording_runtime(production)
