from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from app.application.billing.service import (
    BillingAdminService,
    BillingReconciliationService,
    BillingService,
    PaymentEventProcessor,
)
from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import PaymentEvent, PaymentOrder, Refund
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.base import (
    CheckoutSession,
    ProviderEvent,
    ProviderPaymentState,
    ProviderRefundState,
    RefundSession,
)
from app.infrastructure.payments.fake import FakePaymentProvider
from tests.identity_helpers import identity_settings


async def _seed_user_and_package(session, settings):
    user = User(
        email=f"user-{uuid.uuid4().hex}@example.com",
        normalized_email=f"user-{uuid.uuid4().hex}@example.com",
        role="user",
        email_verified_at=utcnow(),
    )
    # normalized email must match a stable distinct value.
    user.normalized_email = user.email
    session.add(user)
    await session.commit()
    await session.refresh(user)
    package = await BillingAdminService(
        session,
        FakePaymentProvider(settings),
    ).create_package(
        code=f"pkg-{uuid.uuid4().hex}",
        name="Test credits",
        credits=100,
        amount_minor=1000,
        currency="USD",
    )
    return user, package


async def _paid_order(session, settings):
    user, package = await _seed_user_and_package(session, settings)
    provider = FakePaymentProvider(settings)
    service = BillingService(session, settings, provider)
    order = await service.create_order(
        user_id=user.id,
        package_id=str(package.id),
        idempotency_key=str(uuid.uuid4()),
    )
    checkout = await service.checkout(
        user_id=user.id,
        payment_order_id=str(order.id),
        return_url="https://example.test/return",
        idempotency_key=str(uuid.uuid4()),
    )
    event = ProviderEvent(
        event_id=f"evt-{uuid.uuid4().hex}",
        event_type="payment.paid",
        provider_reference=checkout.payment_order.provider_reference or "",
        amount_minor=order.amount_minor,
        currency=order.currency,
    )
    await PaymentEventProcessor(session, provider).ingest(
        event,
        raw_payload={
            "id": event.event_id,
            "type": event.event_type,
            "payment_reference": event.provider_reference,
            "amount_minor": event.amount_minor,
            "currency": event.currency,
        },
        signature_verified=True,
    )
    await session.refresh(order)
    return user, order, provider


def test_out_of_order_payment_event_is_reprocessed(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'out-of-order.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user, package = await _seed_user_and_package(session, settings)
                provider = FakePaymentProvider(settings)
                service = BillingService(session, settings, provider)
                order = await service.create_order(
                    user_id=user.id,
                    package_id=str(package.id),
                    idempotency_key=str(uuid.uuid4()),
                )
                order.provider = "fake"
                order.provider_reference = f"fake_pay_{order.id}"
                await session.commit()

                event = ProviderEvent(
                    event_id="evt-early-paid",
                    event_type="payment.paid",
                    provider_reference=order.provider_reference,
                    amount_minor=order.amount_minor,
                    currency=order.currency,
                )
                processor = PaymentEventProcessor(session, provider)
                await processor.ingest(
                    event,
                    raw_payload={
                        "id": event.event_id,
                        "type": event.event_type,
                        "payment_reference": event.provider_reference,
                        "amount_minor": event.amount_minor,
                        "currency": event.currency,
                    },
                    signature_verified=True,
                )
                row = await session.scalar(
                    select(PaymentEvent).where(
                        PaymentEvent.provider_event_id == event.event_id
                    )
                )
                assert row is not None
                assert row.processed_at is None
                assert row.processing_error == "checkout_not_committed_yet"
                assert (await CreditService(session).balance(user.id)).posted == 0

                order.status = "pending"
                await session.commit()
                assert await processor.reprocess_pending() == 1
                await session.refresh(order)
                assert order.status == "paid"
                assert (await CreditService(session).balance(user.id)).posted == 100
        finally:
            await database.close()

    asyncio.run(run())


def test_partial_full_refund_and_failed_refund_compensation(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'refunds.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user, order, provider = await _paid_order(session, settings)
                admin = BillingAdminService(session, provider)
                assert (await CreditService(session).balance(user.id)).posted == 100

                first = await admin.request_refund(
                    payment_order_id=str(order.id),
                    amount_minor=500,
                    credits=50,
                    idempotency_key=str(uuid.uuid4()),
                )
                assert first.status == "pending"
                assert (await CreditService(session).balance(user.id)).posted == 50

                await PaymentEventProcessor(session, provider).ingest(
                    ProviderEvent(
                        event_id="evt-refund-1",
                        event_type="refund.succeeded",
                        provider_reference=order.provider_reference or "",
                        amount_minor=500,
                        refund_reference=first.provider_refund_reference,
                    ),
                    raw_payload={
                        "id": "evt-refund-1",
                        "type": "refund.succeeded",
                        "payment_reference": order.provider_reference,
                        "amount_minor": 500,
                        "refund_reference": first.provider_refund_reference,
                    },
                    signature_verified=True,
                )
                await session.refresh(order)
                assert order.status == "partially_refunded"
                assert order.refunded_credits == 50
                assert order.refunded_amount_minor == 500

                second_key = str(uuid.uuid4())
                second = await admin.request_refund(
                    payment_order_id=str(order.id),
                    amount_minor=500,
                    credits=50,
                    idempotency_key=second_key,
                )
                replay = await admin.request_refund(
                    payment_order_id=str(order.id),
                    amount_minor=500,
                    credits=50,
                    idempotency_key=second_key,
                )
                assert replay.id == second.id
                assert (await CreditService(session).balance(user.id)).posted == 0

                await PaymentEventProcessor(session, provider).ingest(
                    ProviderEvent(
                        event_id="evt-refund-2",
                        event_type="refund.succeeded",
                        provider_reference=order.provider_reference or "",
                        amount_minor=500,
                        refund_reference=second.provider_refund_reference,
                    ),
                    raw_payload={
                        "id": "evt-refund-2",
                        "type": "refund.succeeded",
                        "payment_reference": order.provider_reference,
                        "amount_minor": 500,
                        "refund_reference": second.provider_refund_reference,
                    },
                    signature_verified=True,
                )
                await session.refresh(order)
                assert order.status == "refunded"
                assert order.refunded_credits == 100
                assert order.refunded_amount_minor == 1000

                refund_debits = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(CreditLedgerEntry)
                        .where(
                            CreditLedgerEntry.entry_type == "refund",
                            CreditLedgerEntry.user_id == user.id,
                        )
                    )
                    or 0
                )
                assert refund_debits == 2

                user2, order2, provider2 = await _paid_order(session, settings)
                failed = await BillingAdminService(
                    session,
                    provider2,
                ).request_refund(
                    payment_order_id=str(order2.id),
                    amount_minor=200,
                    credits=20,
                    idempotency_key=str(uuid.uuid4()),
                )
                assert (await CreditService(session).balance(user2.id)).posted == 80
                await PaymentEventProcessor(session, provider2).ingest(
                    ProviderEvent(
                        event_id="evt-refund-failed",
                        event_type="refund.failed",
                        provider_reference=order2.provider_reference or "",
                        amount_minor=200,
                        refund_reference=failed.provider_refund_reference,
                    ),
                    raw_payload={
                        "id": "evt-refund-failed",
                        "type": "refund.failed",
                        "payment_reference": order2.provider_reference,
                        "amount_minor": 200,
                        "refund_reference": failed.provider_refund_reference,
                    },
                    signature_verified=True,
                )
                await session.refresh(failed)
                assert failed.status == "failed"
                assert (await CreditService(session).balance(user2.id)).posted == 100
        finally:
            await database.close()

    asyncio.run(run())


class ReconcileProvider(FakePaymentProvider):
    name = "fake"

    async def retrieve_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState | None:
        return ProviderPaymentState(
            event_id="provider-query-paid",
            status="paid",
            provider_reference=provider_reference,
            amount_minor=1000,
            currency="USD",
        )

    async def retrieve_refund(
        self,
        provider_refund_reference: str,
    ) -> ProviderRefundState | None:
        del provider_refund_reference
        return None


def test_reconciliation_confirms_payment_without_browser_redirect_trust(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'reconcile.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user, package = await _seed_user_and_package(session, settings)
                provider = ReconcileProvider(settings)
                service = BillingService(session, settings, provider)
                order = await service.create_order(
                    user_id=user.id,
                    package_id=str(package.id),
                    idempotency_key=str(uuid.uuid4()),
                )
                await service.checkout(
                    user_id=user.id,
                    payment_order_id=str(order.id),
                    return_url="https://example.test/success",
                    idempotency_key=str(uuid.uuid4()),
                )
                assert (await CreditService(session).balance(user.id)).posted == 0

                count = await BillingReconciliationService(
                    session,
                    provider,
                ).run_once()
                assert count == 1
                await session.refresh(order)
                assert order.status == "paid"
                assert (await CreditService(session).balance(user.id)).posted == 100
        finally:
            await database.close()

    asyncio.run(run())
