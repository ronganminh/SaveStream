from __future__ import annotations

import asyncio

from app.application.billing.service import BillingAdminService
from app.application.pricing.service import PricingAdminService
from app.infrastructure.db.session import Database
from app.infrastructure.payments.factory import selected_payment_provider
from app.settings import get_app_settings


async def seed() -> None:
    settings = get_app_settings()
    database = Database(settings.database_url)
    try:
        async with database.session() as session:
            await PricingAdminService(session).create_rule(
                version="e2e-duration-v1",
                policy_type="duration_units_v1",
                policy={
                    "unit_seconds": 60,
                    "credits_per_unit": 1,
                    "minimum_credits": 1,
                },
                public_rules=[
                    {
                        "code": "recording_duration",
                        "description": "E2E duration fixture",
                        "unit_seconds": 60,
                        "credits_per_unit": 1,
                    }
                ],
                activate=True,
            )
            await BillingAdminService(
                session,
                selected_payment_provider(settings),
            ).create_package(
                code="e2e-100",
                name="E2E 100 credits",
                credits=100,
                amount_minor=1000,
                currency="USD",
            )
    finally:
        await database.close()


def main() -> None:
    asyncio.run(seed())


if __name__ == "__main__":
    main()
