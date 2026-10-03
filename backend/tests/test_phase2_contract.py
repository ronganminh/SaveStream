from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from app.settings import AppSettings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_frozen_openapi_contract_still_has_unique_operations_and_enums() -> None:
    spec = json.loads(CONTRACT.read_text(encoding="utf-8"))
    operation_ids = []
    for item in spec["paths"].values():
        for method, operation in item.items():
            if method in {"get", "post", "put", "patch", "delete"}:
                operation_ids.append(operation["operationId"])

    assert spec["openapi"] == "3.1.0"
    assert spec["info"]["version"] == "0.1.0"
    assert len(operation_ids) == len(set(operation_ids))
    assert spec["components"]["schemas"]["RecordingStatus"]["enum"] == [
        "queued",
        "resolving",
        "waiting_live",
        "recording",
        "processing",
        "uploading",
        "completed",
        "failed",
        "stop_requested",
        "stopped",
        "waiting_for_cloud_slot",
        "missed_no_cloud_slot",
    ]
    assert spec["components"]["schemas"]["WatchStatus"]["enum"] == [
        "active",
        "paused",
        "paused_insufficient_credit",
        "paused_error",
        "disabled",
    ]


def test_phase2_health_routes_do_not_pollute_frozen_public_contract() -> None:
    app = create_app(
        AppSettings(
            environment="test",
            database_url="sqlite+aiosqlite:///:memory:",
            redis_url="redis://localhost:6379/15",
            celery_broker_url="memory://",
            celery_result_backend="cache+memory://",
            minio_endpoint="http://localhost:9000",
            minio_access_key="test",
            minio_secret_key="test",
        )
    )
    schema = app.openapi()
    assert schema["info"]["title"] == "SaveStream API"
    assert schema["info"]["version"] == "0.1.0"
    assert "/health/live" not in schema["paths"]
    assert "/health/ready" not in schema["paths"]
