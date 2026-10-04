from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d6_v2_operations_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]
    expected = {
        "/admin/operations/store-transactions": (
            "get",
            "listAdminStoreTransactions",
        ),
        "/admin/operations/local-recordings/metrics": (
            "get",
            "getAdminLocalRecordingMetrics",
        ),
        "/admin/operations/local-recordings/users/{user_id}": (
            "get",
            "listAdminUserLocalSessions",
        ),
        "/admin/operations/rewards/metrics": (
            "get",
            "getAdminRewardMetrics",
        ),
        "/admin/operations/rewards/users/{user_id}/unlock": (
            "post",
            "unlockAdminRewardUser",
        ),
        "/admin/operations/devices/distribution": (
            "get",
            "getAdminDeviceDistribution",
        ),
    }
    for path, (method, operation_id) in expected.items():
        assert paths[path][method]["operationId"] == operation_id

    unlock = paths["/admin/operations/rewards/users/{user_id}/unlock"]["post"]
    assert any(
        parameter["name"] == "X-Admin-Step-Up"
        for parameter in unlock["parameters"]
    )

    schemas = document["components"]["schemas"]
    for name in (
        "AdminStoreTransactionList",
        "AdminLocalRecordingMetrics",
        "AdminLocalSessionList",
        "AdminRewardMetrics",
        "AdminRewardUnlock",
        "AdminDeviceDistribution",
    ):
        assert name in schemas
