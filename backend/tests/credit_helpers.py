from __future__ import annotations

import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.application.credits.service import CreditAdminService
from app.application.pricing.service import PricingAdminService


async def configure_test_pricing(
    session: AsyncSession,
    *,
    version: str = "test-duration-v1",
    credits_per_unit: int = 2,
    unit_seconds: int = 60,
) -> None:
    await PricingAdminService(session).create_rule(
        version=version,
        policy_type="duration_units_v1",
        policy={
            "unit_seconds": unit_seconds,
            "credits_per_unit": credits_per_unit,
            "minimum_credits": 0,
        },
        public_rules=[
            {
                "code": "recording_duration",
                "description": "Test duration pricing",
                "unit_seconds": unit_seconds,
                "credits_per_unit": credits_per_unit,
            }
        ],
        activate=True,
    )


async def grant_test_credits(
    session: AsyncSession,
    user_id: uuid.UUID,
    amount: int = 10_000,
) -> None:
    await CreditAdminService(session).adjust(
        user_id=user_id,
        amount=amount,
        idempotency_key=str(
            uuid.uuid5(uuid.NAMESPACE_URL, f"test-credit:{user_id}:{amount}")
        ),
        reason="test fixture",
    )
