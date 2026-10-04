from __future__ import annotations

import json
from pathlib import Path

from app.domain.identity.types import has_scope, scopes_for_role
from app.api.schemas.support_reports import SupportReportCreateRequest


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d9_support_report_and_overview_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]

    assert paths["/support/reports"]["post"]["operationId"] == "createSupportReport"
    assert paths["/admin/support-reports"]["get"]["operationId"] == (
        "listAdminSupportReports"
    )
    assert paths["/admin/support-reports/{report_id}"]["get"]["operationId"] == (
        "getAdminSupportReport"
    )
    assert paths["/admin/support-reports/{report_id}"]["patch"]["operationId"] == (
        "updateAdminSupportReport"
    )
    assert paths["/admin/overview"]["get"]["operationId"] == "getAdminOverview"

    support_schema = document["components"]["schemas"]["SupportReportCreateRequest"]
    assert set(support_schema["required"]) == {"message"}
    assert set(support_schema["properties"]) == {
        "message",
        "recording_id",
        "diagnostics",
    }

    schemas = document["components"]["schemas"]
    for name in (
        "SupportReportResponse",
        "AdminSupportReport",
        "AdminSupportReportList",
        "AdminDailyMetric",
        "AdminOverview",
    ):
        assert name in schemas


def test_d9_diagnostics_reject_media_payload_keys() -> None:
    SupportReportCreateRequest(
        message="Recorder stopped unexpectedly",
        diagnostics={"app_version": "2.0.0", "error_code": "E_TEST"},
    )

    for key in ("video", "video_bytes", "file", "file_bytes", "media", "blob"):
        try:
            SupportReportCreateRequest(
                message="Recorder stopped unexpectedly",
                diagnostics={key: "forbidden"},
            )
        except ValueError:
            continue
        raise AssertionError(f"diagnostics key {key!r} should be rejected")


def test_d9_role_matrix_for_overview_and_support_reports() -> None:
    owner = scopes_for_role("owner")
    support = scopes_for_role("support")
    finance = scopes_for_role("finance")

    assert has_scope(owner, "admin:reports:read")
    assert has_scope(owner, "admin:support_reports:read")
    assert has_scope(owner, "admin:support_reports:write")

    assert has_scope(finance, "admin:reports:read")
    assert not has_scope(finance, "admin:support_reports:read")
    assert not has_scope(finance, "admin:support_reports:write")

    assert not has_scope(support, "admin:reports:read")
    assert has_scope(support, "admin:support_reports:read")
    assert has_scope(support, "admin:support_reports:write")
