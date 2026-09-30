from __future__ import annotations

import asyncio

from app.application.billing.service import BillingReconciliationService
from app.infrastructure.db.session import Database
from app.infrastructure.payments.factory import selected_payment_provider
from app.settings import get_app_settings


async def reconcile_payments() -> int:
    settings = get_app_settings()
    database = Database(settings.database_url)
    provider = selected_payment_provider(settings)
    try:
        async with database.session() as session:
            return await BillingReconciliationService(
                session,
                provider,
            ).run_once()
    finally:
        await database.close()


def run_payment_reconciliation() -> int:
    return asyncio.run(reconcile_payments())
