from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db_session
from app.api.schemas.billing import (
    Money,
    PublicCreditPackage,
    PublicPricingResponse,
    PublicRecordingRate,
)
from app.application.billing.service import BillingService
from app.application.pricing.service import PricingService
from app.domain.common.errors import ApplicationError
from app.infrastructure.payments.disabled import DisabledPaymentProvider

router = APIRouter(prefix="/v1/public", tags=["Billing"])


def _recording_rate(policy_type: str, policy: dict[str, Any]) -> PublicRecordingRate | None:
    if policy_type != "duration_units_v1":
        return None
    return PublicRecordingRate(
        unit_seconds=int(policy["unit_seconds"]),
        credits_per_unit=int(policy["credits_per_unit"]),
        minimum_credits=int(policy.get("minimum_credits", 0)),
    )


def _limit(*values: int) -> int | None:
    """Smallest configured per-user limit; 0 means not limited."""
    configured = [value for value in values if value > 0]
    return min(configured) if configured else None


def _recording_minutes(credits: int, rate: PublicRecordingRate | None) -> int | None:
    if rate is None or rate.credits_per_unit == 0:
        return None
    return credits // rate.credits_per_unit * rate.unit_seconds // 60


@router.get(
    "/pricing",
    response_model=PublicPricingResponse,
    operation_id="getPublicPricing",
)
async def get_public_pricing(
    request: Request,
    response: Response,
    session: AsyncSession = Depends(get_db_session),
) -> PublicPricingResponse:
    """Active credit packages, recording rate and per-user limits for the pricing page."""
    try:
        rule = await PricingService(session).active_rule()
        rate = _recording_rate(rule.policy_type, dict(rule.policy))
    except ApplicationError:
        rate = None
    # Listing packages never reaches the payment provider.
    packages = await BillingService(
        session, request.app.state.settings, DisabledPaymentProvider()
    ).packages()
    response.headers["Cache-Control"] = "public, max-age=300"
    settings = request.app.state.settings
    return PublicPricingResponse(
        packages=[
            PublicCreditPackage(
                id=str(package.id),
                code=package.code,
                name=package.name,
                credits=package.credits,
                price=Money(amount_minor=package.amount_minor, currency=package.currency),
                recording_minutes=_recording_minutes(package.credits, rate),
            )
            for package in packages
        ],
        recording_rate=rate,
        signup_credits=settings.signup_credits,
        max_channels_per_user=_limit(settings.quota_max_watches_per_user),
        max_concurrent_recordings_per_user=_limit(
            settings.quota_max_active_recordings_per_user,
            settings.watch_max_concurrent_recordings_per_user,
        ),
    )
