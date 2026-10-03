from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d1_admin_users_openapi_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]

    expected = {
        "/admin/users": ("get", "listAdminUsers"),
        "/admin/users/export.csv": ("get", "exportAdminUsersCsv"),
        "/admin/users/{user_id}/detail": ("get", "getAdminUserDetail"),
        "/admin/users/{user_id}/resend-verification": (
            "post",
            "resendAdminUserVerification",
        ),
        "/admin/users/{user_id}/force-password-reset": (
            "post",
            "forceAdminUserPasswordReset",
        ),
        "/admin/users/{user_id}/force-logout": ("post", "forceAdminUserLogout"),
        "/admin/users/{user_id}/profile": ("patch", "updateAdminUserProfile"),
        "/admin/users/{user_id}/notes": ("post", "createAdminUserNote"),
        "/admin/users/{user_id}/notes/{note_id}": ("patch", "updateAdminUserNote"),
        "/admin/search": ("get", "searchAdmin"),
        "/admin/privacy/requests": ("get", "listAdminPrivacyRequests"),
        "/admin/users/{user_id}/privacy/export": (
            "post",
            "exportAdminUserPrivacyData",
        ),
        "/admin/users/{user_id}/privacy/deletion/cancel": (
            "post",
            "cancelAdminUserDeletion",
        ),
        "/admin/users/{user_id}/privacy/deletion/perform": (
            "post",
            "performAdminUserDeletion",
        ),
        "/admin/users/{user_id}/view": ("get", "viewAsAdminUser"),
    }
    for path, (method, operation_id) in expected.items():
        assert paths[path][method]["operationId"] == operation_id

    schemas = document["components"]["schemas"]
    for name in (
        "AdminAction",
        "AdminSupportActionRequest",
        "AdminUserProfileUpdateRequest",
        "AdminUserNoteRequest",
        "AdminUserNote",
        "AdminEntitlement",
        "AdminSearchHit",
        "AdminSearchResponse",
        "AdminPrivacyRequest",
        "AdminPrivacyRequestList",
        "AdminViewAsUser",
    ):
        assert name in schemas

    user_params = {item["name"] for item in paths["/admin/users"]["get"]["parameters"]}
    assert {
        "query",
        "plan",
        "account_status",
        "email_verified",
        "created_from",
        "created_to",
        "purchase_provider",
        "sort_by",
        "sort_order",
    } <= user_params

    view_schema = schemas["AdminViewAsUser"]["properties"]
    assert set(view_schema) == {"user", "entitlement", "balance", "watches", "recordings"}

    for path in (
        "/admin/users/{user_id}/privacy/deletion/cancel",
        "/admin/users/{user_id}/privacy/deletion/perform",
    ):
        parameters = paths[path]["post"]["parameters"]
        assert any(item["name"] == "X-Admin-Step-Up" for item in parameters)
