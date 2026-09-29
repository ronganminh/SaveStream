from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from tests.identity_helpers import identity_settings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_phase4_operation_ids_match_frozen_contract():
    frozen = json.loads(CONTRACT.read_text(encoding="utf-8"))
    app = create_app(identity_settings("sqlite+aiosqlite:///:memory:"))
    generated = app.openapi()

    implemented = {
        "/live-status",
        "/recordings",
        "/recordings/{recording_id}",
        "/recordings/{recording_id}/stop",
        "/recordings/{recording_id}/events",
        "/recordings/{recording_id}/artifacts",
        "/artifacts/{artifact_id}/download-url",
    }
    for frozen_path in implemented:
        actual_path = "/v1" + frozen_path
        assert actual_path in generated["paths"]
        for method, operation in frozen["paths"][frozen_path].items():
            if method not in {"get", "post", "patch", "delete", "put"}:
                continue
            assert (
                generated["paths"][actual_path][method]["operationId"]
                == operation["operationId"]
            )
