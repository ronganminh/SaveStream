from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d7_admin_operations_openapi_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]
    expected = {
        "/admin/storage/summary": ("get", "getAdminStorageSummary"),
        "/admin/storage/orphan-scans": ("post", "createAdminOrphanScan"),
        "/admin/storage/runs/{run_id}": ("get", "getAdminStorageRun"),
        "/admin/storage/orphan-scans/{run_id}/delete": ("post", "deleteAdminOrphanFiles"),
        "/admin/email/logs": ("get", "listAdminEmailLogs"),
        "/admin/email/logs/export.csv": ("get", "exportAdminEmailLogsCsv"),
        "/admin/email/logs/{log_id}/resend": ("post", "resendAdminEmail"),
        "/admin/email/templates": ("get", "listAdminEmailTemplates"),
        "/admin/email/templates/{key}/preview": ("get", "previewAdminEmailTemplate"),
        "/admin/email/templates/{key}": ("put", "updateAdminEmailTemplate"),
        "/admin/email/templates/{key}/test": ("post", "testAdminEmailTemplate"),
        "/admin/broadcasts/preview": ("post", "previewAdminBroadcast"),
        "/admin/broadcasts": ("post", "createAdminBroadcast"),
        "/admin/broadcasts/export.csv": ("get", "exportAdminBroadcastsCsv"),
        "/admin/broadcasts/{broadcast_id}": ("get", "getAdminBroadcast"),
    }
    for path, (method, operation_id) in expected.items():
        assert paths[path][method]["operationId"] == operation_id

    schemas = document["components"]["schemas"]
    for name in (
        "AdminReasonRequest",
        "AdminOrphanScanRequest",
        "AdminStorageRun",
        "AdminStorageSummary",
        "AdminEmailLog",
        "AdminEmailTemplate",
        "AdminEmailTemplateUpdateRequest",
        "AdminBroadcastPreviewRequest",
        "AdminBroadcastCreateRequest",
        "AdminBroadcast",
    ):
        assert name in schemas

    for path, method in (
        ("/admin/storage/orphan-scans/{run_id}/delete", "post"),
        ("/admin/email/templates/{key}", "put"),
        ("/admin/email/templates/{key}", "delete"),
        ("/admin/broadcasts", "post"),
    ):
        assert any(
            item["name"] == "X-Admin-Step-Up"
            for item in paths[path][method]["parameters"]
        )
