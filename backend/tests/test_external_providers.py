from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import uuid
from dataclasses import replace

import pytest

from app.application.billing.service import BillingAdminService, BillingService, PaymentEventProcessor
from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.email.smtp import SMTPEmailSender
from app.infrastructure.payments.lemonsqueezy import LemonSqueezyPaymentProvider
from tests.identity_helpers import identity_settings


def _settings(database_url: str = "sqlite+aiosqlite:///:memory:"):
    return replace(
        identity_settings(database_url),
        payment_provider="lemonsqueezy",
        payment_provider_base_url="https://api.lemonsqueezy.com/v1",
        payment_provider_api_key="test-api-key",
        payment_webhook_secret="test-webhook-secret",
        lemon_squeezy_store_id="store-1",
        lemon_squeezy_variant_id="variant-1",
    )


class _Response:
    def __init__(self, payload: dict, status_code: int = 200) -> None:
        self._payload = payload
        self.status_code = status_code

    def json(self) -> dict:
        return self._payload

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise RuntimeError(f"http {self.status_code}")


class _AsyncClient:
    response: _Response
    last_post: dict | None = None

    def __init__(self, *args, **kwargs) -> None:
        del args, kwargs

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        del exc_type, exc, tb

    async def post(self, url: str, *, headers: dict, json: dict):
        type(self).last_post = {
            "url": url,
            "headers": headers,
            "json": json,
        }
        return type(self).response


def test_lemon_squeezy_checkout_uses_custom_price_and_local_order_id(monkeypatch) -> None:
    async def run() -> None:
        _AsyncClient.response = _Response(
            {
                "data": {
                    "type": "checkouts",
                    "id": "checkout-123",
                    "attributes": {
                        "url": "https://store.lemonsqueezy.com/checkout/abc",
                    },
                }
            }
        )
        monkeypatch.setattr(
            "app.infrastructure.payments.lemonsqueezy.httpx.AsyncClient",
            _AsyncClient,
        )
        provider = LemonSqueezyPaymentProvider(_settings())
        checkout = await provider.create_checkout(
            order_id="order-local-123",
            amount_minor=1500,
            currency="USD",
            return_url="https://savestream.online/billing/success",
        )

        assert checkout.provider_reference == "checkout:checkout-123"
        assert checkout.checkout_url.startswith("https://")
        request = _AsyncClient.last_post
        assert request is not None
        assert request["url"].endswith("/checkouts")
        attributes = request["json"]["data"]["attributes"]
        assert attributes["custom_price"] == 1500
        assert (
            attributes["checkout_data"]["custom"]["payment_order_id"]
            == "order-local-123"
        )
        assert attributes["checkout_options"]["discount"] is False

    asyncio.run(run())


def _signed_order_created(settings, payment_order_id: str, order_id: str = "42"):
    payload = {
        "meta": {
            "event_name": "order_created",
            "custom_data": {
                "payment_order_id": payment_order_id,
            },
        },
        "data": {
            "type": "orders",
            "id": order_id,
            "attributes": {
                "status": "paid",
                "subtotal": 1000,
                "currency": "USD",
                "refunded_amount": 0,
            },
        },
    }
    raw = json.dumps(payload, separators=(",", ":")).encode()
    signature = hmac.new(
        settings.payment_webhook_secret.encode(),
        raw,
        hashlib.sha256,
    ).hexdigest()
    return raw, signature


def test_lemon_squeezy_webhook_signature_and_local_order_mapping(tmp_path) -> None:
    async def run() -> None:
        database_url = f"sqlite+aiosqlite:///{tmp_path / 'lemon.db'}"
        settings = _settings(database_url)
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="lemon@example.com",
                    normalized_email="lemon@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)

                provider = LemonSqueezyPaymentProvider(settings)
                package = await BillingAdminService(
                    session,
                    provider,
                ).create_package(
                    code="lemon-100",
                    name="Lemon 100",
                    credits=100,
                    amount_minor=1000,
                    currency="USD",
                )
                order = await BillingService(
                    session,
                    settings,
                    provider,
                ).create_order(
                    user_id=user.id,
                    package_id=str(package.id),
                    idempotency_key=str(uuid.uuid4()),
                )
                order.provider = provider.name
                order.provider_reference = "checkout:checkout-123"
                order.status = "pending"
                await session.commit()

                raw, signature = _signed_order_created(
                    settings,
                    str(order.id),
                )
                event = provider.verify_and_parse_webhook(
                    raw,
                    {"X-Signature": signature},
                )
                assert event.payment_order_id == str(order.id)
                assert event.provider_reference == "42"
                assert event.event_type == "payment.paid"

                await PaymentEventProcessor(session, provider).ingest(
                    event,
                    raw_payload=json.loads(raw),
                    signature_verified=True,
                )
                await session.refresh(order)
                assert order.provider_reference == "42"
                assert order.status == "paid"
                assert (await CreditService(session).balance(user.id)).posted == 100

                with pytest.raises(ApplicationError):
                    provider.verify_and_parse_webhook(
                        raw,
                        {"X-Signature": "forged"},
                    )
        finally:
            await database.close()

    asyncio.run(run())


def test_authenticated_starttls_smtp(monkeypatch) -> None:
    calls: list[object] = []

    class FakeSMTP:
        def __init__(self, host: str, port: int, timeout: int) -> None:
            calls.append(("connect", host, port, timeout))

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, tb) -> None:
            del exc_type, exc, tb

        def starttls(self, *, context) -> None:
            assert context is not None
            calls.append("starttls")

        def login(self, username: str, password: str) -> None:
            calls.append(("login", username, password))

        def send_message(self, message) -> None:
            calls.append(("send", message["To"], message["Subject"]))

    monkeypatch.setattr("app.infrastructure.email.smtp.smtplib.SMTP", FakeSMTP)
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        smtp_host="smtp-relay.brevo.com",
        smtp_port=587,
        smtp_username="smtp-login@example.test",
        smtp_password="smtp-key",
        smtp_starttls=True,
        email_from="SaveStream <no-reply@savestream.online>",
    )
    SMTPEmailSender(settings).send(
        to="customer@example.test",
        subject="Verify",
        text="verification body",
    )

    assert calls[0] == ("connect", "smtp-relay.brevo.com", 587, 10)
    assert calls[1] == "starttls"
    assert calls[2] == ("login", "smtp-login@example.test", "smtp-key")
    assert calls[3] == ("send", "customer@example.test", "Verify")
