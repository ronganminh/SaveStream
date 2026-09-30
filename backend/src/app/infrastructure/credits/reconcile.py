from __future__ import annotations

import asyncio
import logging

from sqlalchemy import select

from app.application.credits.service import CreditReconciliationService
from app.infrastructure.db.credit_models import CreditAccount
from app.infrastructure.db.session import Database
from app.settings import get_app_settings

logger = logging.getLogger("savestream.credits.reconcile")


async def reconcile_all() -> int:
    settings = get_app_settings()
    database = Database(settings.database_url)
    inconsistent = 0
    try:
        async with database.session() as session:
            user_ids = list(
                (await session.scalars(select(CreditAccount.user_id))).all()
            )
            service = CreditReconciliationService(session)
            for user_id in user_ids:
                result = await service.reconcile_account(user_id)
                if not result.consistent:
                    inconsistent += 1
                    logger.error(
                        "credit reconciliation mismatch user_id=%s account=%s ledger=%s reserved=%s available=%s",
                        user_id,
                        result.account_balance,
                        result.ledger_balance,
                        result.reserved,
                        result.available,
                    )
        return inconsistent
    finally:
        await database.close()


def run_reconciliation() -> int:
    return asyncio.run(reconcile_all())
