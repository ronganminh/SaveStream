from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.api.dependencies import get_current_principal
from app.application.billing.service import BillingAdminService
from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.fake import FakePaymentProvider
from app.main import create_app
from tests.identity_helpers import identity_settings


def _signature(secret: str, raw: bytes) -> str:
    return hmac.new(
        secret.encode("utf-8"),
        raw,
        hashlib.sha256,
    ).hexdigest()


def test_payment_api_webhook_signature_and_credit_grant_once(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase7-api.db'}"
    settings = identity_settings(database_url)

    async def seed() -> tuple[AuthPrincipal, str, str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="billing@example.com",
                    normalized_email="billing@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                other = User(
                    email="other-billing@example.com",
                    normalized_email="other-billing@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add_all([user, other])
                await session.commit()
                await session.refresh(user)
                await session.refresh(other)
                admin = BillingAdminService(
                    session,
                    FakePaymentProvider(settings),
                )
                first = await admin.create_package(
                    code="starter",
                    name="Starter",
                    credits=100,
                    amount_minor=1000,
                    currency="USD",
                )
                second = await admin.create_package(
                    code="plus",
                    name="Plus",
                    credits=250,
                    amount_minor=2000,
                    currency="USD",
                )
                return (
                    AuthPrincipal(
                        user.id,
                        uuid.uuid4(),
                        "user",
                        scopes_for_role("user"),
                    ),
                    str(first.id),
                    str(second.id),
                )
        finally:
            await database.close()

    principal, first_package, second_package = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: principal

    with TestClient(app, base_url="https://testserver") as client:
        packages = client.get("/v1/billing/packages")
        assert packages.status_code == 200
        assert len(packages.json()["items"]) == 2

        order_key = str(uuid.uuid4())
        created = client.post(
            "/v1/billing/payment-orders",
            headers={"Idempotency-Key": order_key},
            json={"package_id": first_package},
        )
        assert created.status_code == 201
        order = created.json()
        assert order["status"] == "created"
        assert order["credits"] == 100
        order_id = order["id"]

        replay = client.post(
            "/v1/billing/payment-orders",
            headers={"Idempotency-Key": order_key},
            json={"package_id": first_package},
        )
        assert replay.status_code == 201
        assert replay.json()["id"] == order_id

        conflict = client.post(
            "/v1/billing/payment-orders",
            headers={"Idempotency-Key": order_key},
            json={"package_id": second_package},
        )
        assert conflict.status_code == 409
        assert conflict.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"

        checkout = client.post(
            f"/v1/billing/payment-orders/{order_id}/checkout",
            headers={"Idempotency-Key": str(uuid.uuid4())},
            json={"return_url": "https://example.test/payment-return"},
        )
        assert checkout.status_code == 200
        checkout_order = checkout.json()["payment_order"]
        assert checkout_order["status"] == "pending"
        provider_reference = checkout_order["provider_reference"]
        assert provider_reference

        # Redirect/checkout success is not payment proof.
        balance_before = client.get("/v1/credits/balance")
        assert balance_before.json() == {
            "posted": 0,
            "reserved": 0,
            "available": 0,
        }

        event_payload = {
            "id": "evt-paid-1",
            "type": "payment.paid",
            "payment_reference": provider_reference,
            "amount_minor": 1000,
            "currency": "USD",
        }
        raw = json.dumps(
            event_payload,
            separators=(",", ":"),
        ).encode("utf-8")

        forged = client.post(
            "/v1/webhooks/payments/fake",
            content=raw,
            headers={
                "Content-Type": "application/json",
                "X-Payment-Signature": "forged",
            },
        )
        assert forged.status_code == 400
        assert forged.json()["error"]["code"] == "VALIDATION_ERROR"

        accepted = client.post(
            "/v1/webhooks/payments/fake",
            content=raw,
            headers={
                "Content-Type": "application/json",
                "X-Payment-Signature": _signature(
                    settings.payment_webhook_secret,
                    raw,
                ),
            },
        )
        assert accepted.status_code == 204

        duplicate = client.post(
            "/v1/webhooks/payments/fake",
            content=raw,
            headers={
                "Content-Type": "application/json",
                "X-Payment-Signature": _signature(
                    settings.payment_webhook_secret,
                    raw,
                ),
            },
        )
        assert duplicate.status_code == 204

        paid = client.get(
            f"/v1/billing/payment-orders/{order_id}"
        )
        assert paid.status_code == 200
        assert paid.json()["status"] == "paid"

        balance_after = client.get("/v1/credits/balance")
        assert balance_after.json() == {
            "posted": 100,
            "reserved": 0,
            "available": 100,
        }

    async def assert_grant_once() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                grants = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(CreditLedgerEntry)
                        .where(
                            CreditLedgerEntry.reference_key
                            == f"payment:{order_id}:grant"
                        )
                    )
                    or 0
                )
                assert grants == 1
        finally:
            await database.close()

    asyncio.run(assert_grant_once())
