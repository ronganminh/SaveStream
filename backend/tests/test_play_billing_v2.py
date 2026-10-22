"""Google Play Billing for the Android v2 app (plan §3.2): purchase token as
the order reference, account binding, pending purchases, RTDN, retry and
voided-purchase jobs, and refunds that come after the credits were spent."""

from __future__ import annotations

import asyncio
import base64
import json
import uuid
from dataclasses import replace

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.api.routes import store_webhooks
from app.application.billing.credits import BillingCreditService
from app.application.billing.store import (
    StorePurchaseService,
    play_account_reference,
    store_order_reference,
)
from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import CreditPackage, PaymentEvent, PaymentOrder
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.infrastructure.store.google_play import GooglePlayReceiptVerifier
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings

PACKAGE = "com.savestream.app"
PRODUCT = "savestream.hours.50"


class _Credentials:
    valid = True
    token = "google-oauth-token"


class FakePlay:
    """Just enough of the Android Publisher API."""

    def __init__(self) -> None:
        self.purchases: dict[str, dict[str, object]] = {}
        self.voided: list[dict[str, object]] = []
        self.calls: list[tuple[str, str]] = []
        self.fail_acknowledge = False

    def buy(self, token: str, *, account: str | None, state: int = 0, order_id: str = "GPA.1") -> None:
        payload: dict[str, object] = {
            "purchaseTimeMillis": "1760000000000",
            "purchaseState": state,
            "consumptionState": 0,
            "acknowledgementState": 0,
            "orderId": order_id,
            "productId": PRODUCT,
            "quantity": 1,
        }
        if account is not None:
            payload["obfuscatedExternalAccountId"] = account
        self.purchases[token] = payload

    def handler(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        self.calls.append((request.method, path))
        if path.endswith("/purchases/voidedpurchases"):
            return httpx.Response(200, json={"voidedPurchases": self.voided})
        token = path.split("/tokens/")[-1]
        if request.method == "GET":
            payload = self.purchases.get(token)
            return httpx.Response(200, json=payload) if payload else httpx.Response(404)
        token = token.split(":")[0]
        if path.endswith(":acknowledge"):
            if self.fail_acknowledge:
                return httpx.Response(500)
            self.purchases[token]["acknowledgementState"] = 1
        if path.endswith(":consume"):
            self.purchases[token]["consumptionState"] = 1
        return httpx.Response(200)


def _settings(tmp_path, name: str):
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}"),
        google_play_package_name=PACKAGE,
        google_play_rtdn_audience="https://api.example/v1/webhooks/google-play",
        google_play_rtdn_service_account_email="rtdn@example.iam.gserviceaccount.com",
    )


def _verifier(settings, play: FakePlay) -> GooglePlayReceiptVerifier:
    return GooglePlayReceiptVerifier(
        settings,
        transport=httpx.MockTransport(play.handler),
        credentials=_Credentials(),
        oidc_verifier=lambda _token: {"email": settings.google_play_rtdn_service_account_email},
    )


async def _seed(session) -> User:
    user = User(
        email="buyer@example.com",
        normalized_email="buyer@example.com",
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    session.add(
        CreditPackage(
            code="starter",
            name="Starter",
            credits=3_000,
            amount_minor=1149,
            currency="USD",
            active=True,
            google_play_product_id=PRODUCT,
        )
    )
    await session.commit()
    await session.refresh(user)
    return user


def _run(settings, body) -> None:
    async def wrapped() -> None:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                await body(session)
        finally:
            await database.close()

    asyncio.run(wrapped())


def _rtdn(data: dict[str, object], message_id: str = "m-1") -> bytes:
    return json.dumps(
        {
            "message": {
                "messageId": message_id,
                "data": base64.b64encode(json.dumps(data).encode()).decode(),
            }
        }
    ).encode()


def test_purchase_token_is_the_reference_and_bound_to_the_account(tmp_path) -> None:
    settings = _settings(tmp_path, "token.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        service = StorePurchaseService(session, _verifier(settings, play))
        play.buy("token-1", account=play_account_reference(user.id), order_id="")

        # Promo-code purchases have no orderId: the app sends the token.
        result = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="token-1", receipt="token-1"
        )
        assert result.status == "credited" and result.cloud_minutes_added == 3_000
        order = await session.get(PaymentOrder, result.payment_order_id)
        assert order.provider_reference == store_order_reference("google_play", "", "token-1")
        assert order.provider_reference.startswith("token:") and order.store_token == "token-1"
        assert play.purchases["token-1"]["acknowledgementState"] == 1

        replay = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="token-1", receipt="token-1"
        )
        assert replay.cloud_minutes_added == 0
        assert (await CreditService(session).balance(user.id)).posted == 3_000

        # A token bought by someone else can't be redeemed here.
        play.buy("token-2", account=play_account_reference(uuid.uuid4()))
        with pytest.raises(ApplicationError) as other:
            await service.purchase(
                user_id=user.id, product_id=PRODUCT, transaction_id="GPA.1", receipt="token-2"
            )
        assert other.value.code == "STORE_RECEIPT_INVALID"

        # Builds that don't set the account id are refused once required.
        play.buy("token-3", account=None, order_id="GPA.3")
        strict = StorePurchaseService(
            session, _verifier(settings, play), require_account_reference=True
        )
        with pytest.raises(ApplicationError):
            await strict.purchase(
                user_id=user.id, product_id=PRODUCT, transaction_id="GPA.3", receipt="token-3"
            )

    _run(settings, body)


def test_orders_saved_by_order_id_are_not_credited_twice(tmp_path) -> None:
    settings = _settings(tmp_path, "legacy.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        package = await session.scalar(select(CreditPackage))
        legacy = PaymentOrder(
            user_id=user.id,
            package_id=package.id,
            status="paid",
            credits=3_000,
            amount_minor=1149,
            currency="USD",
            provider="google_play",
            provider_reference="GPA.OLD",
            paid_at=utcnow(),
        )
        session.add(legacy)
        await session.flush()
        await BillingCreditService(session).grant_purchase(
            user_id=user.id,
            payment_order_id=legacy.id,
            credits=3_000,
            idempotency_reference="store:google_play:GPA.OLD:grant",
        )
        await session.commit()

        play.buy("old-token", account=None, order_id="GPA.OLD")
        service = StorePurchaseService(session, _verifier(settings, play))
        result = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="GPA.OLD", receipt="old-token"
        )
        assert result.payment_order_id == legacy.id and result.cloud_minutes_added == 0
        assert (await CreditService(session).balance(user.id)).posted == 3_000

    _run(settings, body)


def test_pending_purchase_is_credited_once_it_settles(tmp_path) -> None:
    settings = _settings(tmp_path, "pending.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        service = StorePurchaseService(session, _verifier(settings, play))
        play.buy("cash-token", account=play_account_reference(user.id), state=2)

        pending = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="GPA.1", receipt="cash-token"
        )
        assert pending.status == "payment_pending" and pending.cloud_minutes_added == 0
        assert (await CreditService(session).balance(user.id)).posted == 0
        order = await session.get(PaymentOrder, pending.payment_order_id)
        assert order.status == "pending" and order.paid_at is None
        # Nothing to acknowledge until the payment goes through.
        assert not any(path.endswith(":acknowledge") for _, path in play.calls)

        play.purchases["cash-token"]["purchaseState"] = 0
        counts = await service.retry_unfinished()
        assert counts == {"checked": 1, "credited": 1, "failed": 0}
        await session.refresh(order)
        assert order.status == "paid" and order.paid_at is not None
        assert (await CreditService(session).balance(user.id)).posted == 3_000
        assert play.purchases["cash-token"]["acknowledgementState"] == 1

    _run(settings, body)


def test_unacknowledged_purchase_is_retried(tmp_path) -> None:
    settings = _settings(tmp_path, "retry.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        service = StorePurchaseService(session, _verifier(settings, play))
        play.buy("ack-token", account=play_account_reference(user.id))
        play.fail_acknowledge = True
        first = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="GPA.1", receipt="ack-token"
        )
        # Credited right away; acknowledge is retried by the job.
        assert first.status == "pending" and first.cloud_minutes_added == 3_000
        order = await session.get(PaymentOrder, first.payment_order_id)
        assert order.failure_code == "store_finalize_pending"

        play.fail_acknowledge = False
        assert (await service.retry_unfinished())["credited"] == 1
        await session.refresh(order)
        assert order.failure_code is None
        assert play.purchases["ack-token"]["acknowledgementState"] == 1
        assert (await CreditService(session).balance(user.id)).posted == 3_000
        assert (await service.retry_unfinished())["checked"] == 0

    _run(settings, body)


def test_refund_after_spending_blocks_recording_until_next_purchase(tmp_path) -> None:
    settings = _settings(tmp_path, "debt.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        service = StorePurchaseService(session, _verifier(settings, play))
        play.buy("spent-token", account=play_account_reference(user.id), order_id="GPA.S")
        bought = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="GPA.S", receipt="spent-token"
        )
        account = await session.scalar(select(CreditAccount).where(CreditAccount.user_id == user.id))
        account.posted_balance = 500  # 2,500 already recorded
        await session.commit()

        play.voided = [{"purchaseToken": "spent-token", "orderId": "GPA.S"}]
        refunds = await _verifier(settings, play).list_voided(utcnow())
        assert await service.reconcile_voided(refunds) == 1
        assert await service.reconcile_voided(refunds) == 0  # idempotent

        balance = await CreditService(session).balance(user.id)
        assert (balance.posted, balance.refund_debt, balance.available) == (0, 2_500, 0)
        allowed, _, _ = await CreditService(session).can_afford(
            user_id=user.id, max_duration_seconds=3600
        )
        assert allowed is False
        with pytest.raises(ApplicationError) as blocked:
            await CreditService(session).reserve_recording(
                user_id=user.id, recording_id=uuid.uuid4(), max_duration_seconds=60
            )
        assert blocked.value.code == "INSUFFICIENT_CREDITS"
        assert blocked.value.details["refund_debt"] == 2_500
        order = await session.get(PaymentOrder, bought.payment_order_id)
        assert order.status == "refunded"

        # The next purchase pays the debt first.
        play.buy("next-token", account=play_account_reference(user.id), order_id="GPA.N")
        await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="GPA.N", receipt="next-token"
        )
        balance = await CreditService(session).balance(user.id)
        assert (balance.posted, balance.refund_debt, balance.available) == (500, 0, 500)
        settled = await session.scalar(
            select(CreditLedgerEntry).where(CreditLedgerEntry.reference_type == "store_refund_debt")
        )
        assert settled.amount == -2_500 and settled.balance_after == 500

    _run(settings, body)


def test_rtdn_test_and_purchased_notifications(tmp_path) -> None:
    settings = _settings(tmp_path, "rtdn.db")
    play = FakePlay()
    verifier = _verifier(settings, play)
    headers = {"Authorization": "Bearer oidc"}

    async def body(session) -> None:
        user = await _seed(session)
        test = await verifier.parse_notification(
            _rtdn({"packageName": PACKAGE, "testNotification": {"version": "1.0"}}), headers
        )
        assert test.kind == "ignored"
        cancelled = await verifier.parse_notification(
            _rtdn(
                {
                    "packageName": PACKAGE,
                    "oneTimeProductNotification": {
                        "notificationType": 2,
                        "purchaseToken": "t",
                        "sku": PRODUCT,
                    },
                }
            ),
            headers,
        )
        assert cancelled.kind == "ignored"
        with pytest.raises(ApplicationError):
            await verifier.parse_notification(
                _rtdn({"packageName": "other.app", "testNotification": {}}), headers
            )

        # PURCHASED for an order the app started while pending: credited.
        service = StorePurchaseService(session, verifier)
        play.buy("rtdn-token", account=play_account_reference(user.id), state=2)
        await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="GPA.1", receipt="rtdn-token"
        )
        play.purchases["rtdn-token"]["purchaseState"] = 0
        purchased = await verifier.parse_notification(
            _rtdn(
                {
                    "packageName": PACKAGE,
                    "oneTimeProductNotification": {
                        "notificationType": 1,
                        "purchaseToken": "rtdn-token",
                        "sku": PRODUCT,
                    },
                }
            ),
            headers,
        )
        assert purchased.kind == "purchased"
        result = await service.handle_purchased_notification(
            product_id=PRODUCT, store_token="rtdn-token", raw_payload={}
        )
        assert result is not None and result.status == "credited"
        assert (await CreditService(session).balance(user.id)).posted == 3_000

        # A purchase the app never reported is kept for support, not credited.
        assert (
            await service.handle_purchased_notification(
                product_id=PRODUCT, store_token="orphan-token", raw_payload={}
            )
            is None
        )
        unclaimed = await session.scalar(
            select(func.count()).select_from(PaymentEvent).where(
                PaymentEvent.event_type == "purchase.unclaimed"
            )
        )
        assert unclaimed == 1

    _run(settings, body)


def test_webhook_acknowledges_test_notifications(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path, "webhook.db")
    create_schema(settings.database_url)
    play = FakePlay()
    monkeypatch.setattr(
        store_webhooks,
        "store_receipt_verifier_for_platform",
        lambda _settings, _platform: _verifier(settings, play),
    )
    app = create_app(settings)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post(
            "/v1/webhooks/google-play",
            content=_rtdn({"packageName": PACKAGE, "testNotification": {"version": "1.0"}}),
            headers={"Authorization": "Bearer oidc", "Content-Type": "application/json"},
        )
    assert response.status_code == 204


def test_android_product_ids_do_not_need_an_apple_id(tmp_path) -> None:
    from app.api.serializers.billing import package_response

    package = CreditPackage(
        code="starter",
        name="Starter",
        credits=3_000,
        amount_minor=1149,
        currency="USD",
        active=True,
        google_play_product_id=PRODUCT,
    )
    package.id = uuid.uuid4()
    ids = package_response(package).store_product_ids
    assert ids is not None and ids.google_play == PRODUCT and ids.app_store is None
