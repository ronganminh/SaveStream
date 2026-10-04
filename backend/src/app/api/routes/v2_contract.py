from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.app_status import (
    AppStatusResponse,
    MaintenanceStatus,
    MinimumSupportedVersions,
)
from app.api.schemas.entitlements import (
    EntitlementLimitsResponse,
    EntitlementResponse,
    LocalEntitlementResponse,
)
from app.application.entitlements.service import EntitlementService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1", tags=["V2"])


def _not_implemented(phase: str) -> None:
    raise ApplicationError(
        "NOT_IMPLEMENTED",
        f"SaveStream V2 endpoint is frozen by B0 and will be implemented in {phase}",
        status_code=501,
        retryable=False,
        details={"phase": phase},
    )


@router.get(
    "/me/entitlement",
    response_model=EntitlementResponse,
    operation_id="getEntitlement",
)
async def get_entitlement(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> EntitlementResponse:
    snapshot = await EntitlementService(
        session,
        request.app.state.settings,
    ).get(principal.user_id)
    return EntitlementResponse(
        plan=snapshot.plan,
        has_purchased=snapshot.has_purchased,
        cloud_minutes_available=snapshot.cloud_minutes_available,
        limits=EntitlementLimitsResponse(
            max_watches=snapshot.max_watches,
            max_concurrent_cloud_recordings=snapshot.max_concurrent_cloud_recordings,
            cloud_retention_days=snapshot.cloud_retention_days,
        ),
        watch_count=snapshot.watch_count,
        local=LocalEntitlementResponse(
            enabled=snapshot.local.enabled,
            unlimited=snapshot.local.unlimited,
            daily_minutes=snapshot.local.daily_minutes,
            minutes_remaining=snapshot.local.minutes_remaining,
            resets_at=snapshot.local.resets_at,
            rewards_used_today=snapshot.local.rewards_used_today,
            rewards_cap_per_day=snapshot.local.rewards_cap_per_day,
            minutes_per_reward=snapshot.local.minutes_per_reward,
            extensions_cap_per_recording=snapshot.local.extensions_cap_per_recording,
            max_concurrent_sessions=snapshot.local.max_concurrent_sessions,
            second_slot_expires_at=snapshot.local.second_slot_expires_at,
        ),
        updated_at=snapshot.updated_at,
    )


@router.get(
    "/app/status",
    response_model=AppStatusResponse,
    operation_id="getAppStatus",
)
async def get_app_status(request: Request) -> AppStatusResponse:
    settings = request.app.state.settings
    return AppStatusResponse(
        min_supported_version=MinimumSupportedVersions(
            android=settings.app_min_supported_android,
            ios=settings.app_min_supported_ios,
        ),
        maintenance=MaintenanceStatus(
            active=settings.maintenance_active,
            eta=settings.maintenance_eta,
        ),
    )
