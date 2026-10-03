from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.api.routes.v2_contract import _not_implemented
from app.domain.common.errors import ApplicationError
from app.main import create_app
from tests.identity_helpers import identity_settings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_v2_b0_operation_ids_match_frozen_contract() -> None:
    frozen = json.loads(CONTRACT.read_text(encoding="utf-8"))
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()

    expected = {
        ("/me/entitlement", "get"): "getEntitlement",
        ("/local-recordings/sessions", "post"): "createLocalRecordingSession",
        (
            "/local-recordings/sessions/{session_id}/extend",
            "post",
        ): "extendLocalRecordingSession",
        (
            "/local-recordings/sessions/{session_id}/finish",
            "post",
        ): "finishLocalRecordingSession",
        ("/local-recordings", "get"): "listLocalRecordings",
        ("/local-recordings/{id}", "delete"): "deleteLocalRecording",
        ("/rewards", "post"): "createReward",
        ("/rewards/{reward_id}", "get"): "getReward",
        ("/webhooks/admob-ssv", "get"): "admobSsvWebhook",
        ("/billing/store-purchases", "post"): "createStorePurchase",
        ("/me/devices/{device_id}", "put"): "upsertDevice",
        ("/me/devices/{device_id}", "delete"): "deleteDevice",
        ("/app/status", "get"): "getAppStatus",
    }
    for (path, method), operation_id in expected.items():
        assert path in frozen["paths"]
        assert frozen["paths"][path][method]["operationId"] == operation_id
        actual_path = "/v1" + path
        assert actual_path in generated["paths"]
        assert generated["paths"][actual_path][method]["operationId"] == operation_id


def test_v2_b0_freezes_additive_contract_values() -> None:
    spec = json.loads(CONTRACT.read_text(encoding="utf-8"))
    schemas = spec["components"]["schemas"]

    assert schemas["AutoRecordState"]["enum"] == [
        "off",
        "active",
        "paused_no_cloud_minutes",
        "waiting_for_cloud_slot",
    ]
    assert schemas["RecordingStatus"]["enum"][-2:] == [
        "waiting_for_cloud_slot",
        "missed_no_cloud_slot",
    ]
    assert "creator_live" in schemas["NotificationType"]["enum"]
    assert "purchase_completed" in schemas["NotificationType"]["enum"]
    assert "watch" in schemas["Notification"]["properties"]["resource_type"]["enum"]

    for code in {
        "PLAN_REQUIRED",
        "WATCH_LIMIT_REACHED",
        "FREE_MINUTES_EXHAUSTED",
        "CREATOR_NOT_LIVE",
        "LOCAL_SLOT_BUSY",
        "EXTENSION_LIMIT_REACHED",
        "REWARD_DAILY_CAP_REACHED",
        "REWARD_LOCKED",
        "STORE_RECEIPT_INVALID",
        "NOT_SOURCE_DEVICE",
        "LOCAL_RECORDING_DISABLED",
        "NOT_IMPLEMENTED",
    }:
        assert code in schemas["ErrorCode"]["enum"]


def test_v2_b0_contract_only_routes_raise_not_implemented() -> None:
    with pytest.raises(ApplicationError) as exc_info:
        _not_implemented("B4")

    exc = exc_info.value
    assert exc.code == "NOT_IMPLEMENTED"
    assert exc.status_code == 501
    assert exc.retryable is False
    assert exc.details == {"phase": "B4"}


def test_v2_b0_public_routes_do_not_require_bearer_auth() -> None:
    spec = json.loads(CONTRACT.read_text(encoding="utf-8"))
    assert not spec["paths"]["/app/status"]["get"].get("security")
    assert not spec["paths"]["/webhooks/admob-ssv"]["get"].get("security")
