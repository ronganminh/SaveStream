from __future__ import annotations

from app.domain.identity.types import has_scope, scopes_for_role


def test_d8_role_matrix_support_owner_finance() -> None:
    support = scopes_for_role("support")
    finance = scopes_for_role("finance")
    owner = scopes_for_role("owner")

    assert has_scope(support, "admin:complaints:read")
    assert has_scope(support, "admin:complaints:write")
    assert has_scope(support, "admin:csv:export")

    assert not has_scope(finance, "admin:complaints:read")
    assert not has_scope(finance, "admin:complaints:write")

    assert has_scope(owner, "admin:complaints:read")
    assert has_scope(owner, "admin:complaints:write")
    assert has_scope(owner, "admin:csv:export")
