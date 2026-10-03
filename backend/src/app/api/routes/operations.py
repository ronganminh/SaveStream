from __future__ import annotations

import hmac

from fastapi import APIRouter, Depends, Header, Request
from fastapi.responses import PlainTextResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.operations import OperationalSnapshotResponse
from app.application.operations.service import OperationsService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, has_scope, is_admin_role

router = APIRouter(include_in_schema=False)


@router.get("/metrics", response_class=PlainTextResponse)
async def metrics(
    request: Request,
    metrics_token: str = Header(default="", alias="X-Metrics-Token"),
    session: AsyncSession = Depends(get_db_session),
) -> PlainTextResponse:
    expected = request.app.state.settings.metrics_token
    if not metrics_token or not hmac.compare_digest(metrics_token, expected):
        raise ApplicationError(
            "FORBIDDEN",
            "Metrics token is invalid",
            status_code=403,
        )
    snapshot = await OperationsService(
        session,
        request.app.state.settings,
    ).snapshot()
    body = request.app.state.metrics_registry.render(snapshot)
    return PlainTextResponse(
        body,
        media_type="text/plain; version=0.0.4; charset=utf-8",
    )


@router.get(
    "/v1/admin/operations/snapshot",
    response_model=OperationalSnapshotResponse,
)
async def admin_operations_snapshot(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> OperationalSnapshotResponse:
    if not is_admin_role(principal.role) or not has_scope(
        principal.scopes, "admin:operations:read"
    ):
        raise ApplicationError(
            "FORBIDDEN",
            "Admin operations permission is required",
            status_code=403,
        )
    if not principal.admin_mfa_verified:
        raise ApplicationError(
            "ADMIN_MFA_REQUIRED",
            "Admin MFA verification is required",
            status_code=403,
        )
    snapshot = await OperationsService(
        session,
        request.app.state.settings,
    ).snapshot()
    return OperationalSnapshotResponse(
        active_recordings=snapshot.active_recordings,
        failed_recordings_recent=snapshot.failed_recordings_recent,
        pending_outbox_events=snapshot.pending_outbox_events,
        unprocessed_payment_events=snapshot.unprocessed_payment_events,
        pending_payment_orders=snapshot.pending_payment_orders,
        paused_error_watches=snapshot.paused_error_watches,
    )
