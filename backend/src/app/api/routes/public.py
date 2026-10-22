from __future__ import annotations

from typing import Any

import asyncio
import re

from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db_session
from app.api.schemas.billing import (
    Money,
    PublicCheckoutChannels,
    PublicCreditPackage,
    PublicPricingResponse,
    PublicRecordingRate,
)
from app.application.billing.service import BillingService
from app.application.creators.avatar_cache import avatar_key
from app.application.pricing.service import PricingService
from app.application.recordings.retention import effective_retention_days
from app.application.runtime_settings import RuntimeSettingsService
from app.domain.common.errors import ApplicationError
from app.infrastructure.creators.avatar_fetch import ALLOWED_AVATAR_TYPES, MAX_AVATAR_BYTES
from app.infrastructure.payments.disabled import DisabledPaymentProvider
from app.settings import AppSettings, store_purchase_platform_enabled

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


async def _checkout_channels(
    session: AsyncSession,
    settings: AppSettings,
) -> PublicCheckoutChannels:
    """Single source of truth for which purchase channels clients may offer.

    Web checkout (PayPal) and Google Play (Android app) are each open only
    when their admin runtime flag is on *and* the provider is configured,
    mirroring the checks the billing routes enforce. The App Store is not
    sold through (no iOS app yet).
    """
    runtime = RuntimeSettingsService(session, settings)
    return PublicCheckoutChannels(
        web=(
            settings.payment_provider != "disabled"
            and await runtime.boolean("payment_web_enabled")
        ),
        app_store=False,
        google_play=(
            store_purchase_platform_enabled(settings.store_purchase_provider, "google_play")
            and await runtime.boolean("payment_google_play_enabled")
        ),
    )


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
    response.headers["Cache-Control"] = "public, max-age=60"
    settings = request.app.state.settings
    # Limits come from the Admin runtime settings that entitlements enforce,
    # so changing them in Admin updates the pricing page too.
    runtime = RuntimeSettingsService(session, settings)
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
        signup_credits=await runtime.integer("signup_credits"),
        max_channels_per_user=_limit(await runtime.integer("pro_max_watches")),
        free_max_channels_per_user=_limit(await runtime.integer("free_max_watches")),
        max_concurrent_recordings_per_user=_limit(
            await runtime.integer("pro_max_concurrent_cloud_recordings")
        ),
        recording_retention_days=(
            await effective_retention_days(session, settings, paid=True) or None
        ),
        trial_recording_retention_days=(
            await effective_retention_days(session, settings, paid=False) or None
        ),
        checkout=await _checkout_channels(session, settings),
    )


_AVATAR_ID = re.compile(r"^[0-9a-f]{32}$")


@router.get(
    "/creator-avatars/{avatar_id}",
    operation_id="getCreatorAvatar",
    response_class=Response,
    responses={200: {"content": {"image/jpeg": {}, "image/webp": {}, "image/png": {}}}},
)
async def get_creator_avatar(avatar_id: str, request: Request) -> Response:
    """Cached copy of a channel's TikTok avatar (stable URL; TikTok's own expire).

    Only ids issued by the avatar cache (random 32-hex) resolve, and only
    raster image types are served.
    """
    if not _AVATAR_ID.fullmatch(avatar_id):
        raise ApplicationError("RESOURCE_NOT_FOUND", "Avatar not found", status_code=404)
    found = await asyncio.to_thread(
        request.app.state.minio.get_bytes,
        avatar_key(avatar_id),
        max_bytes=MAX_AVATAR_BYTES,
    )
    if found is None:
        raise ApplicationError("RESOURCE_NOT_FOUND", "Avatar not found", status_code=404)
    data, content_type = found
    content_type = content_type.split(";")[0].strip().lower()
    if content_type not in ALLOWED_AVATAR_TYPES:
        raise ApplicationError("RESOURCE_NOT_FOUND", "Avatar not found", status_code=404)
    return Response(
        content=data,
        media_type=content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )
