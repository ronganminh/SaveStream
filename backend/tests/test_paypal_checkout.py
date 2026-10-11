from __future__ import annotations

import asyncio
import json
import uuid
from dataclasses import replace

import httpx
import pytest

from app.application.billing.service import BillingAdminService, BillingService
from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.paypal import PayPalPaymentProvider
from tests.identity_helpers import identity_settings


def _settings(database_url: str = "sqlite+aiosqlite:///:memory:"):
    return replace(
        identity_settings(database_url),
        payment_provider="paypal",
        payment_provider_base_url="https://api-m.sandbox.paypal.com",
        paypal_client_id="paypal-client-id",
        paypal_client_secret="paypal-client-secret",
    )


def _paypal_transport(calls: list[str]) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        calls.append(f"{request.method} {request.url.path}")
        if request.url.path == "/v1/oauth2/token":
            assert request.method == "POST"
            assert request.headers["authorization"].startswith("Basic ")
            return httpx.Response(200, json={"access_token": "access-token"})
        if request.url.path == "/v2/checkout/orders" and request.method == "POST":
            payload = json.loads(request.content)
            assert payload["intent"] == "CAPTURE"
            assert payload["purchase_units"][0]["custom_id"]
            assert payload["purchase_units"][0]["amount"] == {
                "currency_code": "USD",
                "value": "9.99",
            }
            return httpx.Response(
                201,
                json={
                    "id": "PAYPAL-ORDER-123",
                    "status": "CREATED",
                    "links": [
                        {
                            "rel": "approve",
                            "href": "https://www.paypal.com/checkoutnow?token=PAYPAL-ORDER-123",
                        }
                    ],
                },
            )
        if (
            request.url.path == "/v2/checkout/orders/PAYPAL-ORDER-123/capture"
            and request.method == "POST"
        ):
            return httpx.Response(
                201,
                json={
                    "id": "PAYPAL-ORDER-123",
                    "status": "COMPLETED",
                    "purchase_units": [
                        {
                            "payments": {
                                "captures": [
                                    {
                                        "id": "CAPTURE-123",
                                        "status": "COMPLETED",
                                        "amount": {
                                            "currency_code": "USD",
                                            "value": "9.99",
                                        },
                                    }
                                ]
                            }
                        }
                    ],
                },
            )
        raise AssertionError(f"Unexpected PayPal request: {request.method} {request.url}")

    return httpx.MockTransport(handler)


def test_paypal_order_creation_and_capture() -> None:
    async def run() -> None:
        calls: list[str] = []
        provider = PayPalPaymentProvider(
            _settings(),
            transport=_paypal_transport(calls),
        )
        checkout = await provider.create_checkout(
            order_id="local-order-1",
            amount_minor=999,
            currency="USD",
            return_url="https://savestream.online/billing/success?order_id=local-order-1",
        )
        assert checkout.provider_reference == "PAYPAL-ORDER-123"
        assert checkout.checkout_url.startswith("https://www.paypal.com/")

        capture = await provider.capture_payment(checkout.provider_reference)
        assert capture.status == "paid"
        assert capture.event_id == "CAPTURE-123"
        assert capture.amount_minor == 999
        assert capture.currency == "USD"
        assert calls.count("POST /v2/checkout/orders/PAYPAL-ORDER-123/capture") == 1

    asyncio.run(run())


def test_paypal_capture_grants_credits_once_and_rejects_swapped_order(tmp_path) -> None:
    async def run() -> None:
        settings = _settings(f"sqlite+aiosqlite:///{tmp_path / 'paypal.db'}")
        calls: list[str] = []
        provider = PayPalPaymentProvider(settings, transport=_paypal_transport(calls))
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="paypal-user@example.com",
                    normalized_email="paypal-user@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                package = await BillingAdminService(session, provider).create_package(
                    code=f"paypal-{uuid.uuid4().hex}",
                    name="Starter",
                    credits=3000,
                    amount_minor=999,
                    currency="USD",
                )
                service = BillingService(session, settings, provider)
                order = await service.create_order(
                    user_id=user.id,
                    package_id=str(package.id),
                    idempotency_key=str(uuid.uuid4()),
                )
                checkout = await service.checkout(
                    user_id=user.id,
                    payment_order_id=str(order.id),
                    return_url=f"https://testserver/billing/success?order_id={order.id}",
                    idempotency_key=str(uuid.uuid4()),
                )
                assert checkout.payment_order.provider_reference == "PAYPAL-ORDER-123"

                with pytest.raises(ApplicationError, match="does not match"):
                    await service.capture(
                        user_id=user.id,
                        payment_order_id=str(order.id),
                        provider_order_id="PAYPAL-ORDER-SWAPPED",
                    )

                paid = await service.capture(
                    user_id=user.id,
                    payment_order_id=str(order.id),
                    provider_order_id="PAYPAL-ORDER-123",
                )
                assert paid.status == "paid"
                assert (await CreditService(session).balance(user.id)).posted == 3000

                replay = await service.capture(
                    user_id=user.id,
                    payment_order_id=str(order.id),
                    provider_order_id="PAYPAL-ORDER-123",
                )
                assert replay.status == "paid"
                assert (await CreditService(session).balance(user.id)).posted == 3000
                assert calls.count("POST /v2/checkout/orders/PAYPAL-ORDER-123/capture") == 1
        finally:
            await database.close()

    asyncio.run(run())
