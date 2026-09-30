from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.application.recordings.service import utcnow
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import AuditLog, Base, User
from app.infrastructure.db.session import Database
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_phase8_admin_rbac_audit_credit_and_metrics(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase8-admin.db'}"
    settings = replace(
        identity_settings(database_url),
        metrics_token="phase8-metrics-secret",
    )

    async def seed() -> tuple[AuthPrincipal, AuthPrincipal, str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                admin = User(
                    email="admin@example.com",
                    normalized_email="admin@example.com",
                    role="admin",
                    email_verified_at=utcnow(),
                )
                user = User(
                    email="member@example.com",
                    normalized_email="member@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add_all([admin, user])
                await session.commit()
                await session.refresh(admin)
                await session.refresh(user)
                return (
                    AuthPrincipal(
                        admin.id,
                        uuid.uuid4(),
                        "admin",
                        scopes_for_role("admin"),
                    ),
                    AuthPrincipal(
                        user.id,
                        uuid.uuid4(),
                        "user",
                        scopes_for_role("user"),
                    ),
                    str(user.id),
                )
        finally:
            await database.close()

    admin_principal, user_principal, user_id = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: user_principal

    with TestClient(app, base_url="https://testserver") as client:
        forbidden = client.get("/v1/admin/users")
        assert forbidden.status_code == 403

        metrics_forbidden = client.get("/metrics")
        assert metrics_forbidden.status_code == 403

        metrics = client.get(
            "/metrics",
            headers={"X-Metrics-Token": settings.metrics_token},
        )
        assert metrics.status_code == 200
        assert "savestream_active_recordings" in metrics.text

        app.dependency_overrides[get_current_principal] = lambda: admin_principal

        users = client.get("/v1/admin/users")
        assert users.status_code == 200
        assert len(users.json()["items"]) == 2

        updated = client.patch(
            f"/v1/admin/users/{user_id}",
            json={"role": "admin"},
        )
        assert updated.status_code == 200
        assert updated.json()["role"] == "admin"

        idem = str(uuid.uuid4())
        adjustment = client.post(
            "/v1/admin/credits/adjustments",
            headers={"Idempotency-Key": idem},
            json={
                "user_id": user_id,
                "amount": 50,
                "reason": "support adjustment",
            },
        )
        assert adjustment.status_code == 200
        assert adjustment.json()["transaction"]["amount"] == 50

        replay = client.post(
            "/v1/admin/credits/adjustments",
            headers={"Idempotency-Key": idem},
            json={
                "user_id": user_id,
                "amount": 50,
                "reason": "support adjustment",
            },
        )
        assert replay.status_code == 200
        assert (
            replay.json()["transaction"]["id"]
            == adjustment.json()["transaction"]["id"]
        )

        audit = client.get("/v1/admin/audit")
        assert audit.status_code == 200
        actions = {item["action"] for item in audit.json()["items"]}
        assert "admin.user.updated" in actions
        assert "admin.credit.adjusted" in actions

        snapshot = client.get("/v1/admin/operations/snapshot")
        assert snapshot.status_code == 200
        assert "pending_outbox_events" in snapshot.json()

    async def verify_audit() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                rows = list((await session.scalars(select(AuditLog))).all())
                assert any(row.action == "admin.user.updated" for row in rows)
                assert any(row.action == "admin.credit.adjusted" for row in rows)
        finally:
            await database.close()

    asyncio.run(verify_audit())
