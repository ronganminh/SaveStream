from __future__ import annotations

import inspect
import re

from fastapi.routing import APIRoute

from app.api.routes.admin import router
from app.domain.identity.types import has_scope, scopes_for_role


ROLES = ("owner", "support", "finance")
SCOPE_PATTERN = re.compile(r'_require_scope\(principal,\s*"([^"]+)"\)')


def _expected_roles(route: APIRoute) -> dict[str, bool]:
    source = inspect.getsource(route.endpoint)
    if "_require_owner(principal" in source:
        return {role: role == "owner" for role in ROLES}

    scopes = SCOPE_PATTERN.findall(source)
    if scopes:
        return {
            role: all(
                has_scope(scopes_for_role(role), scope)
                for scope in scopes
            )
            for role in ROLES
        }

    if "_require_admin(principal" in source:
        return {role: True for role in ROLES}

    raise AssertionError(
        f"{sorted(route.methods)} {route.path} has no recognized admin role guard"
    )


def test_d9_every_admin_endpoint_has_owner_support_finance_matrix() -> None:
    routes = [
        route
        for route in router.routes
        if isinstance(route, APIRoute)
    ]
    matrix = {
        (method, route.path, role): allowed
        for route in routes
        for method in sorted(route.methods)
        for role, allowed in _expected_roles(route).items()
    }

    assert len(matrix) == sum(len(route.methods) for route in routes) * len(ROLES)

    expected = {
        ("GET", "/v1/admin/overview"): {
            "owner": True,
            "support": False,
            "finance": True,
        },
        ("GET", "/v1/admin/reports/revenue.csv"): {
            "owner": True,
            "support": False,
            "finance": True,
        },
        ("GET", "/v1/admin/support-reports"): {
            "owner": True,
            "support": True,
            "finance": False,
        },
        ("PATCH", "/v1/admin/support-reports/{report_id}"): {
            "owner": True,
            "support": True,
            "finance": False,
        },
        ("GET", "/v1/admin/settings"): {
            "owner": True,
            "support": False,
            "finance": False,
        },
        ("PUT", "/v1/admin/settings/{setting_key}"): {
            "owner": True,
            "support": False,
            "finance": False,
        },
        ("POST", "/v1/admin/complaints"): {
            "owner": True,
            "support": True,
            "finance": False,
        },
        ("POST", "/v1/admin/creator-blocks"): {
            "owner": True,
            "support": True,
            "finance": False,
        },
        ("GET", "/v1/admin/payments"): {
            "owner": True,
            "support": True,
            "finance": True,
        },
        ("POST", "/v1/admin/payments/{payment_order_id}/refunds"): {
            "owner": True,
            "support": False,
            "finance": True,
        },
        ("POST", "/v1/admin/credits/adjustments"): {
            "owner": True,
            "support": False,
            "finance": True,
        },
        ("GET", "/v1/admin/email/templates"): {
            "owner": True,
            "support": False,
            "finance": False,
        },
        ("POST", "/v1/admin/broadcasts"): {
            "owner": True,
            "support": False,
            "finance": False,
        },
    }

    for (method, path), roles in expected.items():
        for role, allowed in roles.items():
            assert matrix[(method, path, role)] is allowed
