from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from tests.identity_helpers import identity_settings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_phase3_operation_ids_match_frozen_contract() -> None:
    frozen = json.loads(CONTRACT.read_text(encoding="utf-8"))
    app = create_app(identity_settings("sqlite+aiosqlite:///:memory:"))
    generated = app.openapi()

    implemented = {
        "/auth/register",
        "/auth/verify-email",
        "/auth/resend-verification",
        "/auth/login",
        "/auth/refresh",
        "/auth/logout",
        "/auth/logout-all",
        "/auth/forgot-password",
        "/auth/reset-password",
        "/me",
        "/me/sessions",
        "/me/sessions/{session_id}",
    }
    for frozen_path in implemented:
        actual_path = "/v1" + frozen_path
        assert actual_path in generated["paths"]
        for method, operation in frozen["paths"][frozen_path].items():
            if method not in {"get", "post", "patch", "delete", "put"}:
                continue
            assert generated["paths"][actual_path][method]["operationId"] == operation["operationId"]
