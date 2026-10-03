from __future__ import annotations

import uuid
from dataclasses import dataclass

_USER_SCOPES = {
    "profile:read",
    "profile:write",
    "sessions:read",
    "sessions:write",
    "recordings:read",
    "recordings:write",
    "watches:read",
    "watches:write",
    "credits:read",
    "billing:read",
    "billing:write",
}

ADMIN_ROLES = frozenset({"owner", "support", "finance", "admin"})

_SUPPORT_SCOPES = {
    "admin:users:read",
    "admin:users:write",
    "admin:recordings:read",
    "admin:recordings:write",
    "admin:watches:read",
    "admin:watches:write",
    "admin:complaints:read",
    "admin:complaints:write",
    "admin:payments:read",
    "admin:audit:read",
    "admin:operations:read",
    "admin:csv:export",
}

_FINANCE_SCOPES = {
    "admin:users:read",
    "admin:payments:read",
    "admin:payments:refund",
    "admin:credits:read",
    "admin:credits:adjust",
    "admin:packages:read",
    "admin:packages:write",
    "admin:promotions:read",
    "admin:promotions:write",
    "admin:reports:read",
    "admin:audit:read",
    "admin:operations:read",
    "admin:csv:export",
}

_ROLE_SCOPES: dict[str, frozenset[str]] = {
    "user": frozenset(_USER_SCOPES),
    "owner": frozenset({*_USER_SCOPES, "admin:*"}),
    # Legacy alias kept so sessions created before the D0 role migration continue
    # to resolve to owner-equivalent permissions.
    "admin": frozenset({*_USER_SCOPES, "admin:*"}),
    "support": frozenset({*_USER_SCOPES, *_SUPPORT_SCOPES}),
    "finance": frozenset({*_USER_SCOPES, *_FINANCE_SCOPES}),
}


def is_admin_role(role: str) -> bool:
    return role in ADMIN_ROLES


def canonical_admin_role(role: str) -> str:
    return "owner" if role == "admin" else role


def scopes_for_role(role: str) -> frozenset[str]:
    return _ROLE_SCOPES.get(role, _ROLE_SCOPES["user"])


def has_scope(scopes: frozenset[str], required: str) -> bool:
    return required in scopes or "admin:*" in scopes


@dataclass(frozen=True, slots=True)
class AuthPrincipal:
    user_id: uuid.UUID
    session_id: uuid.UUID
    role: str
    scopes: frozenset[str]
    # Explicit default keeps direct test principals/backward-compatible callers
    # working. Real request principals always set this from persisted session state.
    admin_mfa_verified: bool = True
