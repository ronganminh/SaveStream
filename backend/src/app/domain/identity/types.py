from __future__ import annotations

import uuid
from dataclasses import dataclass

_ROLE_SCOPES: dict[str, frozenset[str]] = {
    "user": frozenset(
        {
            "profile:read",
            "profile:write",
            "sessions:read",
            "sessions:write",
        }
    ),
    "admin": frozenset(
        {
            "profile:read",
            "profile:write",
            "sessions:read",
            "sessions:write",
            "admin:*",
        }
    ),
}


def scopes_for_role(role: str) -> frozenset[str]:
    return _ROLE_SCOPES.get(role, _ROLE_SCOPES["user"])


@dataclass(frozen=True, slots=True)
class AuthPrincipal:
    user_id: uuid.UUID
    session_id: uuid.UUID
    role: str
    scopes: frozenset[str]
