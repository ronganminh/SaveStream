from __future__ import annotations

import asyncio
import uuid

from fastapi.testclient import TestClient

from app.api.dependencies import get_current_principal
from app.application.admin.catalog_d5 import AdminCatalogService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_d5_admin_rbac_and_redeem_rate_limit(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd5-api.db'}"
    settings = identity_settings(database_url)

    async def seed() -> tuple[dict[str, AuthPrincipal], str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                support = User(
                    email="support-d5@example.com",
                    normalized_email="support-d5@example.com",
                    role="support",
                )
                finance = User(
                    email="finance-d5@example.com",
                    normalized_email="finance-d5@example.com",
                    role="finance",
                )
                customer = User(
                    email="customer-d5@example.com",
                    normalized_email="customer-d5@example.com",
                    role="user",
                )
                owner = User(
                    email="owner-d5-api@example.com",
                    normalized_email="owner-d5-api@example.com",
                    role="owner",
                )
                session.add_all([support, finance, customer, owner])
                await session.flush()
                await AdminCatalogService(session).create_promotion(
                    actor_user_id=owner.id,
                    code="RATE60",
                    credits=60,
                    expires_at=None,
                    max_redemptions=None,
                    counts_as_purchase=False,
                )
                await session.commit()
                principals = {
                    role: AuthPrincipal(
                        row.id,
                        uuid.uuid4(),
                        role,
                        scopes_for_role(role),
                    )
                    for role, row in (
                        ("support", support),
                        ("finance", finance),
                        ("user", customer),
                    )
                }
                return principals, str(customer.id)
        finally:
            await database.close()

    principals, _ = asyncio.run(seed())
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()

        app.dependency_overrides[get_current_principal] = lambda: principals["support"]
        assert client.get("/v1/admin/packages").status_code == 403
        assert client.get("/v1/admin/promotions").status_code == 403
        assert (
            client.post(
                "/v1/admin/bulk-grants/preview",
                json={"credits": 30, "filters": {}},
            ).status_code
            == 403
        )

        app.dependency_overrides[get_current_principal] = lambda: principals["finance"]
        assert client.get("/v1/admin/packages").status_code == 200
        assert client.get("/v1/admin/promotions").status_code == 200
        assert (
            client.post(
                "/v1/admin/bulk-grants/preview",
                json={"credits": 30, "filters": {"account_status": "active"}},
            ).status_code
            == 200
        )
        assert (
            client.post(
                "/v1/admin/packages",
                json={
                    "code": "finance-package",
                    "name": "Finance package",
                    "credits": 60,
                    "amount_minor": 199,
                    "display_order": 1,
                    "reason": "Needs step up",
                },
            ).status_code
            == 403
        )

        app.dependency_overrides[get_current_principal] = lambda: principals["user"]
        first = client.post("/v1/credits/redeem", json={"code": "rate60"})
        assert first.status_code == 200
        assert first.json()["cloud_minutes_added"] == 60
        assert first.json()["counts_as_purchase"] is False

        for _ in range(9):
            repeated = client.post("/v1/credits/redeem", json={"code": "rate60"})
            assert repeated.status_code == 409
            assert repeated.json()["error"]["code"] == "PROMOTION_ALREADY_REDEEMED"

        limited = client.post("/v1/credits/redeem", json={"code": "rate60"})
        assert limited.status_code == 429
        assert limited.json()["error"]["code"] == "RATE_LIMITED"

    app.dependency_overrides.clear()
