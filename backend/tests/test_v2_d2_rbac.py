from __future__ import annotations

import asyncio
import uuid

from fastapi.testclient import TestClient

from app.api.dependencies import get_current_principal
from app.application.billing.credits import BillingCreditService
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.main import create_app
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from tests.identity_helpers import identity_settings


def test_d2_finance_rbac_support_is_read_only(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd2-rbac.db'}"
    settings = identity_settings(database_url)

    async def seed() -> tuple[dict[str, AuthPrincipal], str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                support = User(
                    email="support-d2@example.com",
                    normalized_email="support-d2@example.com",
                    role="support",
                )
                finance = User(
                    email="finance-d2@example.com",
                    normalized_email="finance-d2@example.com",
                    role="finance",
                )
                customer = User(
                    email="customer-d2@example.com",
                    normalized_email="customer-d2@example.com",
                    role="user",
                )
                package = CreditPackage(
                    code="starter",
                    name="Starter",
                    credits=3000,
                    amount_minor=999,
                    currency="USD",
                    active=True,
                )
                session.add_all([support, finance, customer, package])
                await session.flush()
                order = PaymentOrder(
                    user_id=customer.id,
                    package_id=package.id,
                    status="paid",
                    credits=3000,
                    amount_minor=999,
                    currency="USD",
                    provider="fake",
                    provider_reference="fake_d2_rbac",
                )
                session.add(order)
                await session.flush()
                await BillingCreditService(session).grant_purchase(
                    user_id=customer.id,
                    payment_order_id=order.id,
                    credits=order.credits,
                )
                await session.commit()
                return (
                    {
                        role: AuthPrincipal(
                            row.id,
                            uuid.uuid4(),
                            role,
                            scopes_for_role(role),
                        )
                        for role, row in (("support", support), ("finance", finance))
                    },
                    str(order.id),
                )
        finally:
            await database.close()

    principals, order_id = asyncio.run(seed())
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.dependency_overrides[get_current_principal] = lambda: principals["support"]
        assert client.get("/v1/admin/payments").status_code == 200
        assert client.get(f"/v1/admin/payments/{order_id}").status_code == 200
        assert client.get("/v1/admin/credits/ledger").status_code == 403
        assert (
            client.get(
                f"/v1/admin/payments/{order_id}/refund-preview",
                params={"amount_minor": 999},
            ).status_code
            == 403
        )
        assert (
            client.post(
                "/v1/admin/credits/adjustments",
                headers={"Idempotency-Key": str(uuid.uuid4())},
                json={
                    "user_id": str(principals["support"].user_id),
                    "amount": 60,
                    "reason": "Support must not touch money",
                },
            ).status_code
            == 403
        )

        app.dependency_overrides[get_current_principal] = lambda: principals["finance"]
        assert client.get("/v1/admin/payments").status_code == 200
        assert client.get("/v1/admin/credits/ledger").status_code == 200
        preview = client.get(
            f"/v1/admin/payments/{order_id}/refund-preview",
            params={"amount_minor": 999},
        )
        assert preview.status_code == 200
        assert preview.json()["corresponding_credits"] == 3000

    app.dependency_overrides.clear()
