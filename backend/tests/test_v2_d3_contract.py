from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d3_admin_recording_openapi_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]

    expected = {
        "/admin/recordings": ("get", "listAdminRecordings"),
        "/admin/recordings/export.csv": ("get", "exportAdminRecordings"),
        "/admin/recordings/{recording_id}": ("get", "getAdminRecording"),
        "/admin/recordings/{recording_id}/stop": ("post", "stopAdminRecording"),
        "/admin/recordings/{recording_id}/retry": ("post", "retryAdminRecording"),
        "/admin/recordings/{recording_id}/retention": (
            "patch",
            "extendAdminRecordingRetention",
        ),
        "/admin/recordings/{recording_id}/playback-access": (
            "post",
            "requestAdminRecordingPlaybackAccess",
        ),
        "/admin/recording-queue": ("get", "getAdminRecordingQueue"),
        "/admin/watches/channels": ("get", "listAdminWatchChannels"),
        "/admin/detector/metrics": ("get", "getAdminDetectorMetrics"),
        "/admin/capacity": ("get", "getAdminRecordingCapacity"),
    }
    for path, (method, operation_id) in expected.items():
        assert paths[path][method]["operationId"] == operation_id

    delete = paths["/admin/recordings/{recording_id}"]["delete"]
    assert delete["operationId"] == "deleteAdminRecording"
    assert any(
        parameter["name"] == "X-Admin-Step-Up"
        for parameter in delete["parameters"]
    )

    schemas = document["components"]["schemas"]
    assert "AdminRecordingListResponse" in schemas
    assert "AdminRecordingReasonRequest" in schemas
    assert "AdminRecordingRetentionRequest" in schemas
    assert "AdminPlaybackAccessResponse" in schemas
    assert "AdminQueueResponse" in schemas
    assert "AdminWatchChannelListResponse" in schemas
    assert "AdminDetectorMetrics" in schemas
    assert "AdminCapacity" in schemas

    playback = paths["/admin/recordings/{recording_id}/playback-access"]["post"]
    assert any(
        parameter["name"] == "X-Admin-Step-Up"
        for parameter in playback["parameters"]
    )
