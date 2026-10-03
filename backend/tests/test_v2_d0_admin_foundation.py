from __future__ import annotations

import asyncio
import time
import uuid
from dataclasses import replace
from datetime import timedelta

from fastapi.testclient import TestClient

from app.api.dependencies import get_current_principal
from app.application.admin.security import AdminSecurityService, _totp
from app.application.identity.service import utcnow
from app.domain.identity.types import AuthPrincipal, has_scope, scopes_for_role
from app.infrastructure.db.models import AuthSession, Base, PasswordCredential, User
from app.infrastructure.db.session import Database
from app.infrastructure.security.passwords import PasswordService
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_d0_admin_role_scope_matrix() -> None:
    owner = scopes_for_role("owner")
    legacy_admin = scopes_for_role("admin")
    support = scopes_for_role("support")
    finance = scopes_for_role("finance")

    assert "admin:*" in owner
    assert "admin:*" in legacy_admin

    assert has_scope(support, "admin:users:read")
    assert has_scope(support, "admin:users:write")
    assert has_scope(support, "admin:recordings:write")
    assert has_scope(support, "admin:payments:read")
    assert not has_scope(support, "admin:payments:refund")
    assert not has_scope(support, "admin:credits:adjust")

    assert has_scope(finance, "admin:users:read")
    assert not has_scope(finance, "admin:users:write")
    assert has_scope(finance, "admin:payments:refund")
    assert has_scope(finance, "admin:credits:adjust")
    assert has_scope(finance, "admin:reports:read")


def test_d0_totp_setup_and_step_up(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd0-security.db'}"
    settings = replace(identity_settings(database_url), jwt_secret="d0-test-jwt-secret")

    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = User(
                    email="owner@example.com",
                    normalized_email="owner@example.com",
                    role="owner",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.flush()

                password = "StrongPass123!"
                session.add(
                    PasswordCredential(
                        user_id=user.id,
                        password_hash=PasswordService().hash(password),
                    )
                )
                auth_session = AuthSession(
                    id=uuid.uuid4(),
                    user_id=user.id,
                    token_family_id=uuid.uuid4(),
                    client_type="web",
                    refresh_token_hash="a" * 64,
                    refresh_history=[],
                    expires_at=utcnow() + timedelta(days=1),
                )
                session.add(auth_session)
                await session.commit()

                principal = AuthPrincipal(
                    user_id=user.id,
                    session_id=auth_session.id,
                    role="owner",
                    scopes=scopes_for_role("owner"),
                    admin_mfa_verified=False,
                )
                service = AdminSecurityService(session, settings)
                setup = await service.begin_setup(principal)
                assert setup.otpauth_uri.startswith("otpauth://totp/")
                assert "<svg" in setup.qr_svg
                assert len(setup.recovery_codes) == 10

                code = _totp(setup.secret, int(time.time()) // 30)
                await service.enable(principal, code)
                await session.refresh(auth_session)
                assert auth_session.admin_mfa_verified_at is not None

                verified_principal = AuthPrincipal(
                    user_id=user.id,
                    session_id=auth_session.id,
                    role="owner",
                    scopes=scopes_for_role("owner"),
                    admin_mfa_verified=True,
                )
                token, expires_at = await service.issue_step_up(
                    verified_principal,
                    password=password,
                    code=code,
                )
                assert token.startswith("asu_")
                assert expires_at <= utcnow() + timedelta(minutes=5, seconds=5)
                grant = await service.verify_step_up(verified_principal, token)
                assert grant.user_id == user.id
        finally:
            await database.close()

    asyncio.run(run())


def test_d0_admin_mfa_rbac_and_step_up_gate(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd0-rbac.db'}"
    settings = identity_settings(database_url)

    async def seed() -> dict[str, object]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                rows = {
                    role: User(
                        email=f"{role}@example.com",
                        normalized_email=f"{role}@example.com",
                        role=role,
                        email_verified_at=utcnow(),
                    )
                    for role in ("owner", "support", "finance", "user")
                }
                session.add_all(rows.values())
                await session.commit()
                for row in rows.values():
                    await session.refresh(row)
                return {role: row.id for role, row in rows.items()}
        finally:
            await database.close()

    ids = asyncio.run(seed())
    app = create_app(settings)

    def principal(role: str, *, verified: bool = True) -> AuthPrincipal:
        return AuthPrincipal(
            user_id=ids[role],  # type: ignore[arg-type]
            session_id=uuid.uuid4(),
            role=role,
            scopes=scopes_for_role(role),
            admin_mfa_verified=verified,
        )

    with TestClient(app, base_url="https://testserver") as client:
        app.dependency_overrides[get_current_principal] = lambda: principal(
            "support", verified=False
        )
        blocked_mfa = client.get("/v1/admin/users")
        assert blocked_mfa.status_code == 403
        assert blocked_mfa.json()["error"]["code"] == "ADMIN_MFA_REQUIRED"

        app.dependency_overrides[get_current_principal] = lambda: principal("support")
        support_users = client.get("/v1/admin/users")
        assert support_users.status_code == 200

        support_money = client.post(
            "/v1/admin/credits/adjustments",
            headers={"Idempotency-Key": str(uuid.uuid4())},
            json={
                "user_id": str(ids["user"]),
                "amount": 10,
                "reason": "not allowed",
            },
        )
        assert support_money.status_code == 403

        app.dependency_overrides[get_current_principal] = lambda: principal("finance")
        finance_users = client.get("/v1/admin/users")
        assert finance_users.status_code == 200
        finance_write = client.patch(
            f"/v1/admin/users/{ids['user']}",
            json={"is_active": False, "reason": "finance cannot suspend users"},
        )
        assert finance_write.status_code == 403

        app.dependency_overrides[get_current_principal] = lambda: principal("owner")
        admins = client.get("/v1/admin/admins")
        assert admins.status_code == 200
        roles = {item["role"] for item in admins.json()["items"]}
        assert {"owner", "support", "finance"} <= roles

        dangerous_without_step_up = client.patch(
            f"/v1/admin/users/{ids['user']}",
            json={"is_active": False, "reason": "security review"},
        )
        assert dangerous_without_step_up.status_code == 403
        assert (
            dangerous_without_step_up.json()["error"]["code"]
            == "ADMIN_STEP_UP_REQUIRED"
        )

    app.dependency_overrides.clear()
