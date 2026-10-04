from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta

from app.application.admin.payments_d2 import AdminFinanceService, utcnow
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.fake import FakePaymentProvider
from tests.identity_helpers import identity_settings


def test_d2_payment_queries_stuck_detection_and_repair(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd2-finance.db'}"
    settings = identity_settings(database_url)

    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = User(
                    email="finance-target@example.com",
                    normalized_email="finance-target@example.com",
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
                session.add_all([user, package])
                await session.flush()

                paid = PaymentOrder(
                    user_id=user.id,
                    package_id=package.id,
                    status="paid",
                    credits=3000,
                    amount_minor=999,
                    currency="USD",
                    provider="app_store",
                    provider_reference="store_tx_missing_grant",
                    paid_at=utcnow(),
                )
                pending = PaymentOrder(
                    user_id=user.id,
                    package_id=package.id,
                    status="pending",
                    credits=3000,
                    amount_minor=999,
                    currency="USD",
                    provider="fake",
                    provider_reference="fake_pending",
                    updated_at=utcnow() - timedelta(minutes=30),
                )
                session.add_all([paid, pending])
                await session.commit()

                service = AdminFinanceService(
                    session, FakePaymentProvider(settings)
                )
                items, cursor, has_more = await service.list_payments(
                    limit=10,
                    cursor=None,
                    user_id=user.id,
                    channel="app_store",
                )
                assert cursor is None
                assert has_more is False
                assert len(items) == 1
                assert items[0]["provider_transaction_id"] == "store_tx_missing_grant"
                assert items[0]["gross_usd_minor"] == 999
                assert items[0]["estimated_store_fee_minor"] == 300
                assert items[0]["estimated_store_fee_rate_bps"] == 3000
                assert items[0]["refund_mode"] == "store_managed"

                detail = await service.payment_detail(str(paid.id))
                assert detail["order"]["user_email"] == "finance-target@example.com"
                assert detail["timeline"][0]["event"] == "order.created"

                stuck, _, _ = await service.stuck_payments(
                    limit=10, cursor=None
                )
                reasons = {item["reason"] for item in stuck}
                assert "paid_missing_credit" in reasons
                assert "pending_too_long" in reasons

                repaired = await service.reconcile_payment(str(paid.id))
                assert repaired["action"] == "credits_repaired"
                repaired_again = await service.reconcile_payment(str(paid.id))
                assert repaired_again["action"] == "no_change"

                ledger, _, _ = await service.list_ledger(
                    limit=10,
                    cursor=None,
                    user_id=user.id,
                    category="purchase",
                )
                assert len(ledger) == 1
                assert ledger[0]["amount"] == 3000
                assert ledger[0]["category"] == "purchase"
        finally:
            await database.close()

    asyncio.run(run())
