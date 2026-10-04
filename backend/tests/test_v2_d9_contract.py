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
    assert paths["/admin/support-reports/export.csv"]["get"]["operationId"] == (
        "exportAdminSupportReports"
    )
    assert paths["/admin/reports/revenue.csv"]["get"]["operationId"] == (
        "exportAdminRevenueReport"
    )
    assert paths["/admin/reports/new-users.csv"]["get"]["operationId"] == (
        "exportAdminNewUsersReport"
    )
    assert paths["/admin/reports/cloud-usage.csv"]["get"]["operationId"] == (
        "exportAdminCloudUsageReport"
    )
    assert paths["/admin/reports/recordings.csv"]["get"]["operationId"] == (
        "exportAdminRecordingStatusReport"
    )

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

    metric_required = set(schemas["AdminDailyMetric"]["required"])
    assert {
        "free_to_pro_weekly",
        "estimated_store_fee_app_store_usd_minor",
        "estimated_store_fee_google_play_usd_minor",
        "recording_total_24h",
        "cloud_minutes_used",
        "recording_status_counts",
    } <= metric_required

    overview_required = set(schemas["AdminOverview"]["required"])
    assert {
        "month_revenue_web_usd_minor",
        "month_revenue_app_store_usd_minor",
        "month_revenue_google_play_usd_minor",
        "month_estimated_store_fee_usd_minor",
    } <= overview_required


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

    try:
        SupportReportCreateRequest(
            message="Nested media should fail",
            diagnostics={"device": {"logs": [{"video": "forbidden"}]}},
        )
    except ValueError:
        pass
    else:
        raise AssertionError("nested media diagnostic payload should be rejected")


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
