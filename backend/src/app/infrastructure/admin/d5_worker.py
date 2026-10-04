from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import func, select

from app.application.admin.bulk_grants_d5 import AdminBulkGrantService
from app.application.admin.catalog_d5 import grant_credits
from app.application.identity.service import utcnow
from app.infrastructure.db.billing_models import AdminBulkGrant, AdminBulkGrantDelivery
from app.infrastructure.db.session import Database
from app.settings import AppSettings, get_app_settings

_RATE_LIMIT_SECONDS = 0.01


async def _bulk_grant(grant_id: uuid.UUID, settings: AppSettings) -> None:
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            grant = await session.get(AdminBulkGrant, grant_id)
            if grant is None or grant.status == "completed":
                return
            grant.status = "running"
            grant.started_at = grant.started_at or utcnow()
            grant.error = None
            await session.commit()

            try:
                filters = dict(grant.filters)
                credits = grant.credits
                counts_as_purchase = grant.counts_as_purchase
                reason = grant.reason
                user_ids = await AdminBulkGrantService(
                    session, settings
                ).matching_user_ids(filters)
                grant.audience_count = len(user_ids)
                grant.total_credits = len(user_ids) * credits
                await session.commit()

                for user_id in user_ids:
                    delivery = await session.scalar(
                        select(AdminBulkGrantDelivery).where(
                            AdminBulkGrantDelivery.bulk_grant_id == grant_id,
                            AdminBulkGrantDelivery.user_id == user_id,
                        )
                    )
                    if delivery is not None and delivery.status == "delivered":
                        continue
                    if delivery is None:
                        delivery = AdminBulkGrantDelivery(
                            bulk_grant_id=grant_id,
                            user_id=user_id,
                            status="queued",
                        )
                        session.add(delivery)
                        await session.flush()
                    try:
                        entry = await grant_credits(
                            session,
                            user_id=user_id,
                            credits=credits,
                            reference_type="bulk_grant",
                            reference_id=str(grant_id),
                            reference_key=f"bulk-grant:{grant_id}:{user_id}",
                            details={
                                "source": "admin_bulk_grant",
                                "reason": reason,
                                "counts_as_purchase": counts_as_purchase,
                            },
                        )
                        delivery.ledger_entry_id = entry.id
                        delivery.status = "delivered"
                        delivery.error = None
                        await session.commit()
                    except Exception as exc:
                        await session.rollback()
                        delivery = await session.scalar(
                            select(AdminBulkGrantDelivery).where(
                                AdminBulkGrantDelivery.bulk_grant_id == grant_id,
                                AdminBulkGrantDelivery.user_id == user_id,
                            )
                        )
                        if delivery is None:
                            delivery = AdminBulkGrantDelivery(
                                bulk_grant_id=grant_id,
                                user_id=user_id,
                            )
                            session.add(delivery)
                        delivery.status = "failed"
                        delivery.error = (str(exc) or type(exc).__name__)[:2000]
                        await session.commit()
                    await asyncio.sleep(_RATE_LIMIT_SECONDS)

                delivered = int(
                    await session.scalar(
                        select(func.count(AdminBulkGrantDelivery.id)).where(
                            AdminBulkGrantDelivery.bulk_grant_id == grant_id,
                            AdminBulkGrantDelivery.status == "delivered",
                        )
                    )
                    or 0
                )
                failed = int(
                    await session.scalar(
                        select(func.count(AdminBulkGrantDelivery.id)).where(
                            AdminBulkGrantDelivery.bulk_grant_id == grant_id,
                            AdminBulkGrantDelivery.status == "failed",
                        )
                    )
                    or 0
                )
                grant = await session.get(AdminBulkGrant, grant_id)
                if grant is None:
                    return
                grant.delivered_count = delivered
                grant.failed_count = failed
                grant.status = "completed"
                grant.completed_at = utcnow()
                await session.commit()
            except Exception as exc:
                await session.rollback()
                grant = await session.get(AdminBulkGrant, grant_id)
                if grant is not None:
                    grant.status = "failed"
                    grant.error = (str(exc) or type(exc).__name__)[:4000]
                    grant.completed_at = utcnow()
                    await session.commit()
                raise
    finally:
        await database.close()


def run_bulk_grant(grant_id: str) -> None:
    asyncio.run(_bulk_grant(uuid.UUID(grant_id), get_app_settings()))
