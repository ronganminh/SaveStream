from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d8_complaints_safety_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]
    expected = {
        "/admin/complaints": {
            "post": "createAdminComplaint",
            "get": "listAdminComplaints",
        },
        "/admin/complaints/{complaint_id}": {
            "get": "getAdminComplaint",
            "patch": "updateAdminComplaint",
        },
        "/admin/creator-blocks": {
            "post": "blockAdminCreator",
        },
        "/admin/creator-blocks/{block_id}/unblock": {
            "post": "unblockAdminCreator",
        },
    }
    for path, methods in expected.items():
        for method, operation_id in methods.items():
            assert paths[path][method]["operationId"] == operation_id

    for path in (
        "/admin/creator-blocks",
        "/admin/creator-blocks/{block_id}/unblock",
    ):
        operation = paths[path]["post"]
        assert any(
            parameter["name"] == "X-Admin-Step-Up"
            for parameter in operation["parameters"]
        )

    schemas = document["components"]["schemas"]
    for name in (
        "AdminComplaint",
        "AdminComplaintList",
        "AdminComplaintCreateRequest",
        "AdminComplaintUpdateRequest",
        "AdminCreatorBlock",
        "AdminCreatorBlockRequest",
        "AdminCreatorUnblockRequest",
    ):
        assert name in schemas

    assert "CREATOR_BLOCKED" in paths["/watches"]["post"]["responses"]["403"]["description"]
    assert "CREATOR_BLOCKED" in paths["/recordings"]["post"]["responses"]["403"]["description"]
    assert "CREATOR_BLOCKED" in paths[
        "/artifacts/{artifact_id}/download-url"
    ]["post"]["responses"]["403"]["description"]
