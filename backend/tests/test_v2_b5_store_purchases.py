from __future__ import annotations

import asyncio
import base64
import json
import uuid
from dataclasses import replace
from types import SimpleNamespace

import httpx
import pytest
from sqlalchemy import func, select

from app.application.billing.catalog import V2_STORE_CATALOG
from app.application.billing.store import StorePurchaseService
from app.application.credits.service import CreditService
from app.application.entitlements.service import EntitlementService
from app.application.recordings.service import utcnow
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import (
    CreditPackage,
    PaymentEvent,
    PaymentOrder,
)
from app.infrastructure.db.credit_models import (
    CreditAccount,
    CreditLedgerEntry,
)
from app.infrastructure.db.models import Base, User, UserNotification
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from appstoreserverlibrary.signed_data_verifier import (
    VerificationException,
    VerificationStatus,
)
from app.infrastructure.store.apple import AppleStoreReceiptVerifier
from app.infrastructure.store.base import VerifiedStoreRefund
from app.infrastructure.store.google_play import GooglePlayReceiptVerifier
from app.infrastructure.store.disabled import DisabledStoreReceiptVerifier
from app.main import create_app
from app.settings import store_purchase_platform_enabled
from app.infrastructure.store.fake import FakeStoreReceiptVerifier
from tests.identity_helpers import identity_settings


async def _user(session, email: str) -> User:
    user = User(
        email=email,
        normalized_email=email.casefold(),
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def _starter(session) -> CreditPackage:
    package = CreditPackage(
        code="starter",
        name="Starter",
        credits=3_000,
        amount_minor=999,
        currency="USD",
        active=True,
        app_store_product_id="savestream.hours.50",
        google_play_product_id="savestream.hours.50",
    )
    session.add(package)
    await session.commit()
    await session.refresh(package)
    return package


def _receipt(
    *,
    platform: str,
    product_id: str,
    transaction_id: str,
) -> str:
    return json.dumps(
        {
            "valid": True,
            "platform": platform,
            "product_id": product_id,
            "transaction_id": transaction_id,
        }
    )


def test_v2_b5_catalog_matches_locked_decisions() -> None:
    assert [
        (
            item.code,
            item.credits,
            item.cloud_minutes,
            item.amount_minor,
            item.product_id,
        )
        for item in V2_STORE_CATALOG
    ] == [
        ("starter", 3_000, 3_000, 999, "savestream.hours.50"),
        ("standard", 9_000, 9_000, 2_499, "savestream.hours.150"),
        ("premium", 24_000, 24_000, 5_999, "savestream.hours.400"),
    ]


def test_android_only_store_provider_does_not_require_enabling_app_store() -> None:
    assert store_purchase_platform_enabled("google_play", "google_play") is True
    assert store_purchase_platform_enabled("google_play", "app_store") is False
    assert store_purchase_platform_enabled("app_store", "app_store") is True
    assert store_purchase_platform_enabled("app_store", "google_play") is False
    assert store_purchase_platform_enabled("live", "app_store") is True
    assert store_purchase_platform_enabled("live", "google_play") is True
    assert store_purchase_platform_enabled("disabled", "google_play") is False


def test_v2_b5_store_purchase_is_verified_idempotent_and_resumes_b2(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b5-purchase.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = await _user(session, "b5-purchase@example.com")
                package = await _starter(session)
                watch = Watch(
                    user_id=user.id,
                    source_type="room_id",
                    source_value="b5-room",
                    active_dedupe_key=uuid.uuid4().hex,
                    status="paused_insufficient_credit",
                    live_status="offline",
                    auto_record=True,
                    notify_on_live=True,
                    next_check_at=None,
                )
                session.add(watch)
                await session.commit()
                verifier = FakeStoreReceiptVerifier("app_store")
                service = StorePurchaseService(session, verifier)
                transaction_id = "apple-txn-001"

                result = await service.purchase(
                    user_id=user.id,
                    product_id=package.app_store_product_id or "",
                    transaction_id=transaction_id,
                    receipt=_receipt(
                        platform="app_store",
                        product_id="savestream.hours.50",
                        transaction_id=transaction_id,
                    ),
                )
                assert result.status == "credited"
                assert result.cloud_minutes_added == 3_000
                assert result.cloud_minutes_available == 3_000
                assert verifier.finalized == [transaction_id]

                await session.refresh(watch)
                assert watch.status == "active"
                assert watch.next_check_at is not None
                entitlement = await EntitlementService(session, settings).get(user.id)
                assert entitlement.plan == "pro"
                assert entitlement.has_purchased is True

                replay = await service.purchase(
                    user_id=user.id,
                    product_id="savestream.hours.50",
                    transaction_id=transaction_id,
                    receipt=_receipt(
                        platform="app_store",
                        product_id="savestream.hours.50",
                        transaction_id=transaction_id,
                    ),
                )
                assert replay.status == "credited"
                assert replay.cloud_minutes_added == 0
                assert replay.cloud_minutes_available == 3_000
                assert (
                    await session.scalar(
                        select(func.count())
                        .select_from(PaymentOrder)
                        .where(PaymentOrder.user_id == user.id)
                    )
                    or 0
                ) == 1
                assert (
                    await session.scalar(
                        select(func.count())
                        .select_from(CreditLedgerEntry)
                        .where(
                            CreditLedgerEntry.user_id == user.id,
                            CreditLedgerEntry.entry_type == "grant",
                            CreditLedgerEntry.reference_type == "payment_order",
                        )
                    )
                    or 0
                ) == 1
                assert (
                    await session.scalar(
                        select(func.count())
                        .select_from(UserNotification)
                        .where(
                            UserNotification.user_id == user.id,
                            UserNotification.kind == "purchase_completed",
                        )
                    )
                    or 0
                ) == 1
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b5_rejects_receipt_or_product_mismatch(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b5-invalid.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "b5-invalid@example.com")
                await _starter(session)
                service = StorePurchaseService(
                    session,
                    FakeStoreReceiptVerifier("google_play"),
                )
                with pytest.raises(ApplicationError) as mismatch:
                    await service.purchase(
                        user_id=user.id,
                        product_id="savestream.hours.50",
                        transaction_id="google-txn-001",
                        receipt=_receipt(
                            platform="google_play",
                            product_id="savestream.hours.150",
                            transaction_id="google-txn-001",
                        ),
                    )
                assert mismatch.value.code == "STORE_RECEIPT_INVALID"
                assert mismatch.value.status_code == 422
                assert (await CreditService(session).balance(user.id)).posted == 0

                with pytest.raises(ApplicationError) as unknown:
                    await service.purchase(
                        user_id=user.id,
                        product_id="savestream.hours.5",
                        transaction_id="google-txn-002",
                        receipt=_receipt(
                            platform="google_play",
                            product_id="savestream.hours.5",
                            transaction_id="google-txn-002",
                        ),
                    )
                assert unknown.value.code == "STORE_RECEIPT_INVALID"
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b5_store_refund_claws_back_only_remaining_credit(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b5-refund.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "b5-refund@example.com")
                await _starter(session)
                verifier = FakeStoreReceiptVerifier("google_play")
                service = StorePurchaseService(session, verifier)
                transaction_id = "google-refund-txn"

                purchased = await service.purchase(
                    user_id=user.id,
                    product_id="savestream.hours.50",
                    transaction_id=transaction_id,
                    receipt=_receipt(
                        platform="google_play",
                        product_id="savestream.hours.50",
                        transaction_id=transaction_id,
                    ),
                )
                order = await session.get(
                    PaymentOrder,
                    purchased.payment_order_id,
                )
                assert order is not None
                account = await session.scalar(
                    select(CreditAccount).where(CreditAccount.user_id == user.id)
                )
                assert account is not None

                # Simulate 2,800 minutes already consumed before the store
                # reports a full refund. Only the 200 remaining can be clawed
                # back; the account must never go negative.
                account.posted_balance = 200
                session.add(
                    CreditLedgerEntry(
                        account_id=account.id,
                        user_id=user.id,
                        entry_type="charge",
                        amount=-2_800,
                        balance_after=200,
                        reference_type="test_usage",
                        reference_id=None,
                        reference_key=f"test:b5:usage:{order.id}",
                        details={"test": True},
                    )
                )
                await session.commit()

                refund = VerifiedStoreRefund(
                    platform="google_play",
                    transaction_id=transaction_id,
                    event_id="google-refund-event-1",
                )
                result = await service.apply_refund(
                    refund,
                    raw_payload={
                        "type": "refund",
                        "transaction_id": transaction_id,
                    },
                )
                assert result.applied is True
                assert result.deducted_credits == 200
                assert (await CreditService(session).balance(user.id)).posted == 0

                await session.refresh(order)
                assert order.status == "refunded"
                assert order.refunded_credits == 3_000
                assert order.refunded_amount_minor == 999
                entitlement = await EntitlementService(session, settings).get(user.id)
                assert entitlement.plan == "free"
                assert entitlement.has_purchased is False

                replay = await service.apply_refund(
                    refund,
                    raw_payload={
                        "type": "refund",
                        "transaction_id": transaction_id,
                    },
                )
                assert replay.applied is False
                assert (await CreditService(session).balance(user.id)).posted == 0
                assert (
                    await session.scalar(
                        select(func.count())
                        .select_from(PaymentEvent)
                        .where(
                            PaymentEvent.provider == "google_play",
                            PaymentEvent.provider_event_id == "google-refund-event-1",
                        )
                    )
                    or 0
                ) == 1
        finally:
            await database.close()

    asyncio.run(run())


class _FakeAppleSignedDataVerifier:
    def verify_and_decode_signed_transaction(self, value: str):
        if value == "refund-jws":
            return SimpleNamespace(
                transactionId="apple-refund-txn",
                productId="savestream.hours.50",
                revocationDate=1_760_000_000_000,
                purchaseDate=1_750_000_000_000,
            )
        return SimpleNamespace(
            transactionId="apple-live-txn",
            productId="savestream.hours.50",
            revocationDate=None,
            purchaseDate=1_750_000_000_000,
        )

    def verify_and_decode_notification(self, value: str):
        assert value == "apple-notification-jws"
        return SimpleNamespace(
            rawNotificationType="REFUND",
            notificationUUID="apple-refund-event",
            data=SimpleNamespace(signedTransactionInfo="refund-jws"),
        )


class _FakeAppleApiClient:
    async def get_transaction_info(self, transaction_id: str):
        assert transaction_id == "apple-live-txn"
        return SimpleNamespace(signedTransactionInfo="server-jws")


@pytest.mark.parametrize('corrupt_phase', ['device', 'server'])
def test_v2_b5_apple_rejects_unsigned_or_tampered_jws_before_credit(
    corrupt_phase: str, tmp_path
) -> None:
    class RejectingSignedVerifier(_FakeAppleSignedDataVerifier):
        def verify_and_decode_signed_transaction(self, value: str):
            if (corrupt_phase == 'device' and value == 'device-jws') or (
                corrupt_phase == 'server' and value == 'server-jws'
            ):
                raise VerificationException(VerificationStatus.VERIFICATION_FAILURE)
            return super().verify_and_decode_signed_transaction(value)

    class CountingAppleClient(_FakeAppleApiClient):
        def __init__(self):
            self.calls = 0

        async def get_transaction_info(self, transaction_id: str):
            self.calls += 1
            return await super().get_transaction_info(transaction_id)

    async def run() -> None:
        settings = replace(
            identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'apple-invalid.db'}"),
            app_store_bundle_id='com.savestream.app',
            app_store_environment='sandbox',
        )
        client = CountingAppleClient()
        verifier = AppleStoreReceiptVerifier(
            settings,
            signed_data_verifier=RejectingSignedVerifier(),
            api_client=client,
        )
        with pytest.raises(ApplicationError) as error:
            await verifier.verify_purchase(
                product_id='savestream.hours.50',
                transaction_id='apple-live-txn',
                receipt='device-jws',
            )
        assert error.value.code == 'STORE_RECEIPT_INVALID'
        assert error.value.status_code == 422
        assert client.calls == (0 if corrupt_phase == 'device' else 1)

    asyncio.run(run())


@pytest.mark.parametrize(
    ('phase', 'field', 'value'),
    [
        ('device', 'productId', 'savestream.hours.400'),
        ('device', 'transactionId', 'another-apple-transaction'),
        ('device', 'revocationDate', 1_760_000_000_000),
        ('server', 'productId', 'savestream.hours.400'),
        ('server', 'transactionId', 'another-apple-transaction'),
        ('server', 'revocationDate', 1_760_000_000_000),
    ],
)
def test_v2_b5_apple_rejects_mismatched_and_revoked_transactions(
    phase: str, field: str, value: object, tmp_path
) -> None:
    class MismatchingAppleVerifier(_FakeAppleSignedDataVerifier):
        def verify_and_decode_signed_transaction(self, receipt: str):
            transaction = super().verify_and_decode_signed_transaction(receipt)
            if receipt == ('device-jws' if phase == 'device' else 'server-jws'):
                setattr(transaction, field, value)
            return transaction

    async def run() -> None:
        settings = replace(
            identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'apple-mismatch.db'}"),
            app_store_bundle_id='com.savestream.app',
            app_store_environment='sandbox',
        )
        verifier = AppleStoreReceiptVerifier(
            settings,
            signed_data_verifier=MismatchingAppleVerifier(),
            api_client=_FakeAppleApiClient(),
        )
        with pytest.raises(ApplicationError) as error:
            await verifier.verify_purchase(
                product_id='savestream.hours.50',
                transaction_id='apple-live-txn',
                receipt='device-jws',
            )
        assert error.value.code == 'STORE_RECEIPT_INVALID'
        assert error.value.status_code == 422

    asyncio.run(run())


def test_v2_b5_live_apple_verifier_uses_server_transaction_and_signed_refund(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b5-apple-live.db'}"),
            app_store_bundle_id="online.savestream.app",
            app_store_environment="sandbox",
            app_store_private_key="unused-in-injected-test",
            app_store_key_id="KEYID",
            app_store_issuer_id="issuer",
        )
        verifier = AppleStoreReceiptVerifier(
            settings,
            signed_data_verifier=_FakeAppleSignedDataVerifier(),
            api_client=_FakeAppleApiClient(),
        )
        purchase = await verifier.verify_purchase(
            product_id="savestream.hours.50",
            transaction_id="apple-live-txn",
            receipt="device-jws",
        )
        assert purchase.platform == "app_store"
        assert purchase.product_id == "savestream.hours.50"
        assert purchase.transaction_id == "apple-live-txn"
        assert purchase.needs_acknowledge is False
        assert purchase.needs_consume is False

        refund = await verifier.verify_refund_notification(
            json.dumps({"signedPayload": "apple-notification-jws"}).encode("utf-8"),
            {},
        )
        assert refund == VerifiedStoreRefund(
            platform="app_store",
            transaction_id="apple-refund-txn",
            event_id="apple-refund-event",
        )

    asyncio.run(run())


class _FakeGoogleCredentials:
    valid = True
    token = "google-oauth-token"


@pytest.mark.parametrize("status_code", [400, 404, 410])
def test_v2_b5_google_invalid_purchase_token_is_terminal(
    tmp_path,
    status_code: int,
) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / f'b5-google-invalid-{status_code}.db'}"
            ),
            google_play_package_name="com.savestream.app",
        )
        verifier = GooglePlayReceiptVerifier(
            settings,
            transport=httpx.MockTransport(
                lambda _request: httpx.Response(status_code)
            ),
            credentials=_FakeGoogleCredentials(),
        )

        with pytest.raises(ApplicationError) as invalid:
            await verifier.verify_purchase(
                product_id="savestream.hours.50",
                transaction_id="invalid-google-transaction",
                receipt="invalid-google-token",
            )

        assert invalid.value.code == "STORE_RECEIPT_INVALID"
        assert invalid.value.status_code == 422
        assert invalid.value.retryable is False

    asyncio.run(run())


def test_v2_b5_live_google_verifier_gets_acknowledges_consumes_and_parses_rtdn(
    tmp_path,
) -> None:
    async def run() -> None:
        seen: list[tuple[str, str]] = []

        def handler(request: httpx.Request) -> httpx.Response:
            seen.append((request.method, request.url.path))
            assert request.headers["authorization"] == ("Bearer google-oauth-token")
            if request.method == "GET":
                return httpx.Response(
                    200,
                    json={
                        "purchaseTimeMillis": "1750000000000",
                        "purchaseState": 0,
                        "consumptionState": 0,
                        "orderId": "GPA.1234-5678-9012-34567",
                        "acknowledgementState": 0,
                        "purchaseToken": "purchase-token",
                        "productId": "savestream.hours.50",
                        "quantity": 1,
                    },
                )
            return httpx.Response(200)

        settings = replace(
            identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b5-google-live.db'}"),
            google_play_package_name="online.savestream.app",
            google_play_rtdn_audience="https://api.savestream.online/v1/webhooks/google-play",
            google_play_rtdn_service_account_email=("rtdn@example.iam.gserviceaccount.com"),
            store_purchase_timeout_seconds=3.0,
        )
        verifier = GooglePlayReceiptVerifier(
            settings,
            transport=httpx.MockTransport(handler),
            credentials=_FakeGoogleCredentials(),
            oidc_verifier=lambda token: {
                "email": "rtdn@example.iam.gserviceaccount.com",
                "token": token,
            },
        )
        purchase = await verifier.verify_purchase(
            product_id="savestream.hours.50",
            transaction_id="GPA.1234-5678-9012-34567",
            receipt="purchase-token",
        )
        assert purchase.needs_acknowledge is True
        assert purchase.needs_consume is True
        assert purchase.store_token == "purchase-token"
        await verifier.finalize_purchase(purchase)

        assert [method for method, _ in seen] == ["GET", "POST", "POST"]
        assert seen[1][1].endswith(":acknowledge")
        assert seen[2][1].endswith(":consume")

        rtdn_data = {
            "version": "1.0",
            "packageName": "online.savestream.app",
            "eventTimeMillis": "1750000000000",
            "voidedPurchaseNotification": {
                "purchaseToken": "purchase-token",
                "orderId": "GPA.1234-5678-9012-34567",
                "productType": 2,
                "refundType": 1,
            },
        }
        envelope = {
            "message": {
                "messageId": "google-rtdn-event-1",
                "data": base64.b64encode(json.dumps(rtdn_data).encode("utf-8")).decode("ascii"),
            }
        }
        refund = await verifier.verify_refund_notification(
            json.dumps(envelope).encode("utf-8"),
            {"Authorization": "Bearer oidc-token"},
        )
        assert refund == VerifiedStoreRefund(
            platform="google_play",
            transaction_id="GPA.1234-5678-9012-34567",
            event_id="google-rtdn-event-1",
        )

    asyncio.run(run())


def test_v2_b5_disabled_store_fails_closed(tmp_path) -> None:
    async def run() -> None:
        verifier = DisabledStoreReceiptVerifier("app_store")
        with pytest.raises(ApplicationError) as disabled:
            await verifier.verify_purchase(
                product_id="savestream.hours.50",
                transaction_id="disabled-txn",
                receipt="ignored",
            )
        assert disabled.value.status_code == 503
        assert disabled.value.code == "SERVICE_UNAVAILABLE"

    asyncio.run(run())


def test_v2_b5_runtime_openapi_has_real_store_routes(tmp_path) -> None:
    settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b5-openapi.db'}")
    generated = create_app(settings).openapi()
    purchase = generated["paths"]["/v1/billing/store-purchases"]["post"]
    assert purchase["operationId"] == "createStorePurchase"
    assert "501" not in purchase["responses"]
    assert generated["paths"]["/v1/webhooks/app-store"]["post"]["operationId"] == "appStoreWebhook"
    assert (
        generated["paths"]["/v1/webhooks/google-play"]["post"]["operationId"] == "googlePlayWebhook"
    )
