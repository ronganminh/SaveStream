from __future__ import annotations

import asyncio

from sqlalchemy import select

from app.application.admin.bulk_grants_d5 import AdminBulkGrantService
from app.application.admin.catalog_d5 import AdminCatalogService, PromotionRedemptionService
from app.application.entitlements.service import EntitlementService
from app.infrastructure.admin.d5_worker import _bulk_grant
from app.infrastructure.db.billing_models import AdminBulkGrant, AdminBulkGrantDelivery
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.models import Base, OutboxEvent, User
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def test_d5_bulk_grant_preview_worker_and_idempotency(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd5-bulk.db'}"
    settings = identity_settings(database_url)

    async def seed_and_create() -> str:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                owner = User(
                    email="owner-bulk@example.com",
                    normalized_email="owner-bulk@example.com",
                    role="owner",
                )
                user_a = User(
                    email="a-bulk@example.com",
                    normalized_email="a-bulk@example.com",
                    role="user",
                    is_active=True,
                )
                user_b = User(
                    email="b-bulk@example.com",
                    normalized_email="b-bulk@example.com",
                    role="user",
                    is_active=True,
                )
                locked = User(
                    email="locked-bulk@example.com",
                    normalized_email="locked-bulk@example.com",
                    role="user",
                    is_active=False,
                )
                session.add_all([owner, user_a, user_b, locked])
                await session.flush()

                promo = await AdminCatalogService(session).create_promotion(
                    actor_user_id=owner.id,
                    code="BULKPRO",
                    credits=5,
                    expires_at=None,
                    max_redemptions=None,
                    counts_as_purchase=True,
                )
                await session.commit()
                await PromotionRedemptionService(session).redeem(
                    user_id=user_b.id,
                    code=str(promo["code"]),
                )

                service = AdminBulkGrantService(session, settings)
                preview = await service.preview(
                    credits=30,
                    filters={"account_status": "active", "plan": "free"},
                )
                assert preview == {
                    "audience_count": 1,
                    "credits_per_user": 30,
                    "total_credits": 30,
                }
                grant = await service.create(
                    actor_user_id=owner.id,
                    credits=30,
                    counts_as_purchase=False,
                    reason="Customer goodwill",
                    filters={"account_status": "active", "plan": "free"},
                )
                await session.commit()
                outbox = await session.scalar(
                    select(OutboxEvent).where(
                        OutboxEvent.topic == "admin.bulk_grant",
                        OutboxEvent.aggregate_id == str(grant.id),
                    )
                )
                assert outbox is not None
                return str(grant.id)
        finally:
            await database.close()

    grant_id = asyncio.run(seed_and_create())
    asyncio.run(_bulk_grant(__import__("uuid").UUID(grant_id), settings))
    asyncio.run(_bulk_grant(__import__("uuid").UUID(grant_id), settings))

    async def verify() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                grant = await session.get(AdminBulkGrant, __import__("uuid").UUID(grant_id))
                assert grant is not None
                assert grant.status == "completed"
                assert grant.audience_count == 1
                assert grant.delivered_count == 1
                assert grant.failed_count == 0

                deliveries = list(
                    (
                        await session.scalars(
                            select(AdminBulkGrantDelivery).where(
                                AdminBulkGrantDelivery.bulk_grant_id == grant.id
                            )
                        )
                    ).all()
                )
                assert len(deliveries) == 1
                assert deliveries[0].status == "delivered"

                entries = list(
                    (
                        await session.scalars(
                            select(CreditLedgerEntry).where(
                                CreditLedgerEntry.reference_type == "bulk_grant",
                                CreditLedgerEntry.reference_id == grant_id,
                            )
                        )
                    ).all()
                )
                assert len(entries) == 1
                assert entries[0].amount == 30
                assert entries[0].details["counts_as_purchase"] is False

                recipient = await session.get(User, deliveries[0].user_id)
                assert recipient is not None
                entitlement = await EntitlementService(session, settings).get(
                    recipient.id
                )
                assert entitlement.plan == "free"

                account = await session.scalar(
                    select(CreditAccount).where(
                        CreditAccount.user_id == recipient.id
                    )
                )
                assert account is not None
                assert account.posted_balance == 30
        finally:
            await database.close()

    asyncio.run(verify())
