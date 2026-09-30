from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from tests.identity_helpers import identity_settings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_phase5_watch_operations_and_enums_match_frozen_contract() -> None:
    frozen = json.loads(CONTRACT.read_text(encoding="utf-8"))
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()

    for frozen_path in {
        "/watches",
        "/watches/{watch_id}",
        "/watches/{watch_id}/resume",
    }:
        actual_path = "/v1" + frozen_path
        assert actual_path in generated["paths"]
        for method, operation in frozen["paths"][frozen_path].items():
            if method not in {"get", "post", "patch", "delete", "put"}:
                continue
            assert (
                generated["paths"][actual_path][method]["operationId"]
                == operation["operationId"]
            )

    assert frozen["components"]["schemas"]["WatchStatus"]["enum"] == [
        "active",
        "paused",
        "paused_insufficient_credit",
        "paused_error",
        "disabled",
    ]


def test_phase5_does_not_add_unfrozen_watch_sse_endpoint() -> None:
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()
    assert "/v1/watches/{watch_id}/events" not in generated["paths"]
