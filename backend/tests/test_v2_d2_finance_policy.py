from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import select

from app.application.billing.credits import BillingCreditService
from app.application.billing.service import BillingAdminService
from app.application.credits.service import CreditAdminService
from app.application.entitlements.service import EntitlementService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.fake import FakePaymentProvider
from tests.identity_helpers import identity_settings


def test_d2_refund_clawback_and_purchase_flag(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd2-policy.db'}"
    settings = identity_settings(database_url)

    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                gift_user = User(
                    email="gift@example.com",
                    normalized_email="gift@example.com",
                    role="user",
                )
                buyer = User(
                    email="buyer@example.com",
                    normalized_email="buyer@example.com",
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
                session.add_all([gift_user, buyer, package])
                await session.flush()

                gift_service = CreditAdminService(session)
                await gift_service.adjust(
                    user_id=gift_user.id,
                    amount=100,
                    idempotency_key=str(uuid.uuid4()),
                    reason="Promotional gift",
                    counts_as_purchase=False,
                    commit=False,
                )
                free = await EntitlementService(session, settings).get(gift_user.id)
                assert free.plan == "free"
                assert free.has_purchased is False

                await gift_service.adjust(
                    user_id=gift_user.id,
                    amount=100,
                    idempotency_key=str(uuid.uuid4()),
                    reason="Purchased-equivalent manual grant",
                    counts_as_purchase=True,
                    commit=False,
                )
                pro = await EntitlementService(session, settings).get(gift_user.id)
                assert pro.plan == "pro"
                assert pro.has_purchased is True

                web_order = PaymentOrder(
                    user_id=buyer.id,
                    package_id=package.id,
                    status="paid",
                    credits=package.credits,
                    amount_minor=package.amount_minor,
                    currency="USD",
                    provider="fake",
                    provider_reference="fake_paid_order",
                )
                store_order = PaymentOrder(
                    user_id=buyer.id,
                    package_id=package.id,
                    status="paid",
                    credits=package.credits,
                    amount_minor=package.amount_minor,
                    currency="USD",
                    provider="app_store",
                    provider_reference="store_tx_1",
                )
                session.add_all([web_order, store_order])
                await session.flush()

                await BillingCreditService(session).grant_purchase(
                    user_id=buyer.id,
                    payment_order_id=web_order.id,
                    credits=web_order.credits,
                )
                await CreditAdminService(session).adjust(
                    user_id=buyer.id,
                    amount=-2990,
                    idempotency_key=str(uuid.uuid4()),
                    reason="Simulate prior cloud usage",
                    commit=False,
                )
                await session.commit()

                refund = await BillingAdminService(
                    session,
                    FakePaymentProvider(settings),
                ).request_refund(
                    payment_order_id=str(web_order.id),
                    amount_minor=999,
                    credits=3000,
                    idempotency_key=str(uuid.uuid4()),
                )
                assert refund.status == "pending"
                hold = await session.scalar(
                    select(CreditLedgerEntry).where(
                        CreditLedgerEntry.reference_key
                        == f"refund:{refund.id}:debit"
                    )
                )
                assert hold is not None
                assert hold.amount == -10
                assert hold.balance_after == 0
                assert hold.details["requested_credits"] == 3000
                assert hold.details["deducted_credits"] == 10

                with pytest.raises(ApplicationError) as exc_info:
                    await BillingAdminService(
                        session,
                        FakePaymentProvider(settings),
                    ).request_refund(
                        payment_order_id=str(store_order.id),
                        amount_minor=999,
                        credits=3000,
                        idempotency_key=str(uuid.uuid4()),
                    )
                assert exc_info.value.code == "STORE_REFUND_MANAGED"
        finally:
            await database.close()

    asyncio.run(run())
