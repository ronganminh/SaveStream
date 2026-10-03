from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d0_admin_openapi_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]

    expected_operations = {
        "/admin/security/mfa": ("get", "getAdminMfaStatus"),
        "/admin/security/mfa/setup": ("post", "beginAdminMfaSetup"),
        "/admin/security/mfa/enable": ("post", "enableAdminMfa"),
        "/admin/security/mfa/verify": ("post", "verifyAdminMfa"),
        "/admin/step-up": ("post", "createAdminStepUp"),
        "/admin/admins": ("get", "listAdminAccounts"),
        "/admin/admins/{user_id}": ("patch", "updateAdminRole"),
        "/admin/admins/{user_id}/mfa/reset": ("post", "resetAdminMfa"),
        "/admin/audit": ("get", "listAdminAudit"),
    }
    for path, (method, operation_id) in expected_operations.items():
        assert paths[path][method]["operationId"] == operation_id

    schemas = document["components"]["schemas"]
    for name in (
        "AdminMfaStatus",
        "AdminMfaSetup",
        "AdminMfaCodeRequest",
        "AdminStepUpRequest",
        "AdminStepUpResponse",
        "AdminRoleUpdateRequest",
        "AdminMfaResetRequest",
        "AdminUser",
        "AdminAdminList",
        "AdminAuditLog",
        "AdminAuditList",
    ):
        assert name in schemas

    roles = schemas["User"]["properties"]["role"]["enum"]
    assert roles == ["user", "owner", "support", "finance", "admin"]
    assert schemas["User"]["properties"]["admin_mfa_enabled"]["type"] == "boolean"
    assert schemas["User"]["properties"]["admin_mfa_verified"]["type"] == "boolean"

    step_up = paths["/admin/admins/{user_id}"]["patch"]["parameters"]
    assert any(parameter["name"] == "X-Admin-Step-Up" for parameter in step_up)

    audit_parameters = {
        parameter["name"] for parameter in paths["/admin/audit"]["get"]["parameters"]
    }
    assert {
        "actor_user_id",
        "resource_type",
        "action",
        "created_from",
        "created_to",
    } <= audit_parameters
