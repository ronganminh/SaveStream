from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.application.identity.service import utcnow
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.admin_models import AdminUserNote
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditAccount
from app.infrastructure.db.models import AuditLog, AuthSession, Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_d1_admin_users_support_rbac_search_and_view(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd1-users.db'}"
    settings = replace(identity_settings(database_url), signup_credits=0)

    async def seed() -> dict[str, uuid.UUID]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                support = User(
                    email="support@example.com",
                    normalized_email="support@example.com",
                    role="support",
                    email_verified_at=utcnow(),
                )
                finance = User(
                    email="finance@example.com",
                    normalized_email="finance@example.com",
                    role="finance",
                    email_verified_at=utcnow(),
                )
                free = User(
                    email="free@example.com",
                    normalized_email="free@example.com",
                    display_name="Free User",
                    role="user",
                    email_verified_at=utcnow(),
                )
                pro = User(
                    email="pro@example.com",
                    normalized_email="pro@example.com",
                    display_name="Pro User",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add_all([support, finance, free, pro])
                await session.flush()

                package = CreditPackage(
                    code="d1-pack",
                    name="D1 pack",
                    credits=60,
                    amount_minor=199,
                    currency="USD",
                    active=True,
                )
                session.add(package)
                await session.flush()
                session.add(
                    PaymentOrder(
                        user_id=pro.id,
                        package_id=package.id,
                        status="paid",
                        credits=60,
                        amount_minor=199,
                        currency="USD",
                        provider="web",
                        provider_reference="d1-order",
                        paid_at=utcnow(),
                    )
                )
                session.add(CreditAccount(user_id=pro.id, posted_balance=60))
                session.add(
                    Watch(
                        user_id=free.id,
                        source_type="username",
                        source_value="creator",
                        active_dedupe_key="d1-watch",
                        resolved_username="creator",
                        status="active",
                        live_status="offline",
                        auto_record=False,
                    )
                )
                session.add(
                    Recording(
                        user_id=free.id,
                        source_type="username",
                        source_value="creator",
                        status="completed",
                        quality="best",
                        container="mp4",
                        duration_seconds=10,
                        bytes_recorded=1024,
                        estimated_max_cost=1,
                        actual_cost=1,
                    )
                )
                session.add(
                    AuthSession(
                        id=uuid.uuid4(),
                        user_id=free.id,
                        token_family_id=uuid.uuid4(),
                        client_type="web",
                        refresh_token_hash="a" * 64,
                        refresh_history=[],
                        user_agent="D1 Browser",
                        ip_address="127.0.0.1",
                        expires_at=utcnow().replace(year=utcnow().year + 1),
                    )
                )
                await session.commit()
                return {
                    "support": support.id,
                    "finance": finance.id,
                    "free": free.id,
                    "pro": pro.id,
                }
        finally:
            await database.close()

    ids = asyncio.run(seed())
    app = create_app(settings)

    def principal(role: str) -> AuthPrincipal:
        return AuthPrincipal(
            user_id=ids[role],
            session_id=uuid.uuid4(),
            role=role,
            scopes=scopes_for_role(role),
            admin_mfa_verified=True,
        )

    with TestClient(app, base_url="https://testserver") as client:
        app.dependency_overrides[get_current_principal] = lambda: principal("support")

        free_list = client.get("/v1/admin/users", params={"plan": "free"})
        assert free_list.status_code == 200
        assert any(item["email"] == "free@example.com" for item in free_list.json()["items"])

        pro_list = client.get("/v1/admin/users", params={"plan": "pro"})
        assert pro_list.status_code == 200
        pro_item = next(item for item in pro_list.json()["items"] if item["email"] == "pro@example.com")
        assert pro_item["plan"] == "pro"
        assert pro_item["latest_purchase_provider"] == "web"

        search = client.get("/v1/admin/search", params={"q": "free@example.com"})
        assert search.status_code == 200
        assert search.json()["items"][0]["type"] == "user"

        note = client.post(
            f"/v1/admin/users/{ids['free']}/notes",
            json={"body": "Customer asked about a recording.", "reason": "Support follow-up"},
        )
        assert note.status_code == 200
        assert note.json()["body"].startswith("Customer asked")

        view = client.get(
            f"/v1/admin/users/{ids['free']}/view",
            params={"reason": "Investigating support ticket"},
        )
        assert view.status_code == 200
        payload = view.json()
        assert payload["user"]["email"] == "free@example.com"
        assert payload["watches"]
        assert payload["recordings"]
        rendered = str(payload).lower()
        assert "artifact" not in rendered
        assert "download_url" not in rendered
        assert "storage_key" not in rendered

        csv_export = client.get("/v1/admin/users/export.csv")
        assert csv_export.status_code == 200
        assert "free@example.com" in csv_export.text
        assert "pro@example.com" in csv_export.text

        support_money = client.post(
            "/v1/admin/credits/adjustments",
            headers={"Idempotency-Key": str(uuid.uuid4())},
            json={
                "user_id": str(ids["free"]),
                "amount": 10,
                "reason": "Support must not change money",
            },
        )
        assert support_money.status_code == 403

        dangerous = client.post(
            f"/v1/admin/users/{ids['free']}/privacy/deletion/cancel",
            json={"reason": "Customer changed their mind"},
        )
        assert dangerous.status_code == 403
        assert dangerous.json()["error"]["code"] == "ADMIN_STEP_UP_REQUIRED"

        app.dependency_overrides[get_current_principal] = lambda: principal("finance")

        finance_read = client.get(f"/v1/admin/users/{ids['free']}/detail")
        assert finance_read.status_code == 200

        finance_write = client.patch(
            f"/v1/admin/users/{ids['free']}/profile",
            json={"display_name": "Changed", "reason": "Finance must not edit user"},
        )
        assert finance_write.status_code == 403

    app.dependency_overrides.clear()

    async def verify_audit() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                notes = list((await session.scalars(select(AdminUserNote))).all())
                assert len(notes) == 1
                actions = {
                    row.action for row in (await session.scalars(select(AuditLog))).all()
                }
                assert "admin.user.note_created" in actions
                assert "admin.user.viewed_as" in actions
                assert "admin.users.exported" in actions
        finally:
            await database.close()

    asyncio.run(verify_audit())
