from __future__ import annotations

import asyncio
import csv
import io
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, Query, Request, Response
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.admin import (
    AdminActionResponse,
    AdminAdminListResponse,
    AdminEntitlementResponse,
    AdminCreditAdjustmentRequest,
    AdminCreditAdjustmentResponse,
    AdminMfaCodeRequest,
    AdminMfaResetRequest,
    AdminMfaSetupResponse,
    AdminMfaStatusResponse,
    AdminPrivacyRequestListResponse,
    AdminPrivacyRequestResponse,
    AdminRecordingListResponse,
    AdminRefundRequest,
    AdminRefundResponse,
    AdminRetryRecordingResponse,
    AdminSearchHit,
    AdminSearchResponse,
    AdminRoleUpdateRequest,
    AdminStepUpRequest,
    AdminStepUpResponse,
    AdminSupportActionRequest,
    AdminUserDetailResponse,
    AdminUserListResponse,
    AdminUserNoteRequest,
    AdminUserNoteResponse,
    AdminUserNotificationResponse,
    AdminUserProfileUpdateRequest,
    AdminUserSessionResponse,
    AdminUserResponse,
    AdminUserUpdateRequest,
    AdminViewAsUserResponse,
    AuditLogListResponse,
)
from app.api.schemas.admin_d2 import (
    AdminLedgerEntryResponse,
    AdminLedgerListResponse,
    AdminPaymentOrderDetailResponse,
    AdminPaymentOrderListResponse,
    AdminPaymentOrderResponse,
    AdminReconcilePaymentResponse,
    AdminRefundPreviewResponse,
    AdminReservationReleaseResponse,
    AdminStuckPaymentListResponse,
    AdminStuckPaymentResponse,
    AdminStuckReservationListResponse,
    AdminStuckReservationResponse,
)
from app.api.schemas.admin_d3 import (
    AdminCapacityResponse,
    AdminDetectorMetricsResponse,
    AdminPlaybackAccessResponse,
    AdminQueueItemResponse,
    AdminQueueResponse,
    AdminRecordingReasonRequest,
    AdminRecordingRetentionRequest,
    AdminWatchChannelListResponse,
    AdminWatchChannelResponse,
)
from app.api.schemas.admin_d4 import (
    AdminRuntimeSettingListResponse,
    AdminRuntimeSettingResetRequest,
    AdminRuntimeSettingResponse,
    AdminRuntimeSettingUpdateRequest,
    AdminSystemStatusResponse,
)
from app.api.schemas.admin_d5 import (
    AdminBulkGrantCreateRequest,
    AdminBulkGrantDeliveryListResponse,
    AdminBulkGrantDeliveryResponse,
    AdminBulkGrantPreviewRequest,
    AdminBulkGrantPreviewResponse,
    AdminBulkGrantResponse,
    AdminPackageCreateRequest,
    AdminPackageListResponse,
    AdminPackageResponse,
    AdminPackageUpdateRequest,
    AdminPromotionCreateRequest,
    AdminPromotionListResponse,
    AdminPromotionRedemptionListResponse,
    AdminPromotionRedemptionResponse,
    AdminPromotionResponse,
    AdminPromotionUpdateRequest,
)
from app.api.schemas.admin_d7 import (
    AdminBroadcastCreateRequest,
    AdminBroadcastListResponse,
    AdminBroadcastPreviewRequest,
    AdminBroadcastPreviewResponse,
    AdminBroadcastResponse,
    AdminEmailLogListResponse,
    AdminEmailLogResponse,
    AdminEmailPreviewResponse,
    AdminEmailTemplateResponse,
    AdminEmailTemplateUpdateRequest,
    AdminEmailTestRequest,
    AdminOrphanScanRequest,
    AdminReasonRequest,
    AdminStorageRunResponse,
    AdminStorageSummaryResponse,
)
from app.api.schemas.credits import CreditBalanceResponse
from app.api.schemas.recordings import Pagination, RecordingResponse
from app.api.serializers.admin import admin_user_response, audit_log_response
from app.api.serializers.billing import payment_order_response
from app.api.serializers.credits import transaction_response
from app.api.serializers.recordings import recording_response
from app.api.serializers.watches import watch_response
from app.application.admin.bulk_grants_d5 import AdminBulkGrantService
from app.application.admin.catalog_d5 import AdminCatalogService
from app.application.admin.operations_d7 import AdminOperationsService
from app.application.admin.payments_d2 import AdminFinanceService
from app.application.admin.recordings_d3 import AdminRecordingService
from app.application.runtime_settings import RuntimeSettingsService
from app.application.admin.security import AdminSecurityService
from app.application.admin.service import AdminService
from app.application.admin.system_d4 import AdminSystemStatusService
from app.application.audit.service import AuditContext, AuditService
from app.application.entitlements.service import EntitlementSnapshot
from app.application.identity.service import ip_hint
from app.application.privacy.service import PrivacyService
from app.application.billing.service import BillingAdminService
from app.application.credits.service import CreditAdminService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, has_scope, is_admin_role
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.payments.factory import selected_payment_provider

router = APIRouter(
    prefix="/v1/admin",
    tags=["Admin"],
    include_in_schema=False,
)


def _context(request: Request) -> AuditContext:
    client_ip = request.client.host if request.client else None
    return AuditContext(
        request_id=getattr(request.state, "request_id", None),
        ip_address=client_ip,
        user_agent=request.headers.get("user-agent"),
    )


def _require_admin(principal: AuthPrincipal, *, mfa: bool = True) -> None:
    if not is_admin_role(principal.role):
        raise ApplicationError(
            "FORBIDDEN",
            "Admin permission is required",
            status_code=403,
        )
    if mfa and not principal.admin_mfa_verified:
        raise ApplicationError(
            "ADMIN_MFA_REQUIRED",
            "Admin MFA verification is required",
            status_code=403,
        )


def _require_scope(
    principal: AuthPrincipal,
    scope: str,
    *,
    mfa: bool = True,
) -> None:
    _require_admin(principal, mfa=mfa)
    if not has_scope(principal.scopes, scope):
        raise ApplicationError(
            "FORBIDDEN",
            "Required admin permission is missing",
            status_code=403,
            details={"missing_scopes": [scope]},
        )


def _require_owner(principal: AuthPrincipal, *, mfa: bool = True) -> None:
    _require_admin(principal, mfa=mfa)
    if "admin:*" not in principal.scopes:
        raise ApplicationError(
            "FORBIDDEN",
            "Owner permission is required",
            status_code=403,
        )


async def _require_step_up(
    *,
    principal: AuthPrincipal,
    session: AsyncSession,
    request: Request,
    token: str | None,
) -> None:
    if not token:
        # Compatibility for direct legacy Phase 8 principals. The D0 migration
        # rewrites persisted `admin` users to `owner`, so production requests
        # use the MFA + step-up path below.
        if principal.role == "admin":
            return
        raise ApplicationError(
            "ADMIN_STEP_UP_REQUIRED",
            "Step-up authentication is required",
            status_code=403,
        )
    await AdminSecurityService(session, request.app.state.settings).verify_step_up(
        principal, token
    )


async def _user_with_summary(
    service: AdminService,
    user,
) -> AdminUserResponse:
    entitlement, balance, provider = await service.user_summary(user)
    return admin_user_response(
        user,
        plan=entitlement.plan,
        cloud_minutes_available=balance.available,
        latest_purchase_provider=provider,
    )


def _entitlement_response(snapshot: EntitlementSnapshot) -> AdminEntitlementResponse:
    return AdminEntitlementResponse(
        plan=snapshot.plan,
        has_purchased=snapshot.has_purchased,
        cloud_minutes_available=snapshot.cloud_minutes_available,
        max_watches=snapshot.max_watches,
        max_concurrent_cloud_recordings=snapshot.max_concurrent_cloud_recordings,
        cloud_retention_days=snapshot.cloud_retention_days,
        watch_count=snapshot.watch_count,
    )


async def _admin_recording_responses(
    service: AdminRecordingService,
    recordings: list[Recording],
) -> list[RecordingResponse]:
    positions = await service.queue_positions(recordings)
    retention_by_user: dict[uuid.UUID, int] = {}
    responses: list[RecordingResponse] = []
    for recording in recordings:
        days = retention_by_user.get(recording.user_id)
        if days is None:
            days = await service.retention_days_for_user(recording.user_id)
            retention_by_user[recording.user_id] = days
        responses.append(
            recording_response(
                recording,
                retention_days=days,
                queue_position=positions.get(recording.id),
            )
        )
    return responses


@router.get("/security/mfa", response_model=AdminMfaStatusResponse)
async def admin_mfa_status(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminMfaStatusResponse:
    _require_admin(principal, mfa=False)
    enabled, verified = await AdminSecurityService(
        session, request.app.state.settings
    ).status(principal)
    return AdminMfaStatusResponse(enabled=enabled, verified=verified)


@router.post("/security/mfa/setup", response_model=AdminMfaSetupResponse)
async def setup_admin_mfa(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminMfaSetupResponse:
    _require_admin(principal, mfa=False)
    setup = await AdminSecurityService(
        session, request.app.state.settings
    ).begin_setup(principal)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.mfa.setup_started",
        resource_type="user",
        resource_id=str(principal.user_id),
        context=_context(request),
    )
    await session.commit()
    return AdminMfaSetupResponse(
        secret=setup.secret,
        otpauth_uri=setup.otpauth_uri,
        qr_svg=setup.qr_svg,
        recovery_codes=setup.recovery_codes,
    )


@router.post("/security/mfa/enable", response_model=AdminMfaStatusResponse)
async def enable_admin_mfa(
    payload: AdminMfaCodeRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminMfaStatusResponse:
    _require_admin(principal, mfa=False)
    await AdminSecurityService(session, request.app.state.settings).enable(
        principal, payload.code
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.mfa.enabled",
        resource_type="user",
        resource_id=str(principal.user_id),
        context=_context(request),
    )
    await session.commit()
    return AdminMfaStatusResponse(enabled=True, verified=True)


@router.post("/security/mfa/verify", response_model=AdminMfaStatusResponse)
async def verify_admin_mfa(
    payload: AdminMfaCodeRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminMfaStatusResponse:
    _require_admin(principal, mfa=False)
    await AdminSecurityService(session, request.app.state.settings).verify(
        principal, payload.code
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.mfa.verified",
        resource_type="auth_session",
        resource_id=str(principal.session_id),
        context=_context(request),
    )
    await session.commit()
    return AdminMfaStatusResponse(enabled=True, verified=True)


@router.post("/step-up", response_model=AdminStepUpResponse)
async def admin_step_up(
    payload: AdminStepUpRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStepUpResponse:
    _require_admin(principal)
    token, expires_at = await AdminSecurityService(
        session, request.app.state.settings
    ).issue_step_up(
        principal,
        password=payload.password,
        code=payload.totp_code,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.step_up.completed",
        resource_type="auth_session",
        resource_id=str(principal.session_id),
        context=_context(request),
    )
    await session.commit()
    return AdminStepUpResponse(token=token, expires_at=expires_at)


@router.get("/admins", response_model=AdminAdminListResponse)
async def list_admin_accounts(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminAdminListResponse:
    _require_owner(principal)
    page = await AdminService(session, request.app.state.settings).list_admins(
        limit=limit,
        cursor=cursor,
    )
    return AdminAdminListResponse(
        items=[admin_user_response(item) for item in page.items],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
    )


@router.patch("/admins/{user_id}", response_model=AdminUserResponse)
async def update_admin_role(
    user_id: str,
    payload: AdminRoleUpdateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = AdminService(session, request.app.state.settings)
    user, previous_role = await service.set_admin_role(
        actor_user_id=principal.user_id,
        user_id=user_id,
        role=payload.role,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.role.changed",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"role": previous_role},
        after_state={"role": user.role},
    )
    await session.commit()
    await session.refresh(user)
    return admin_user_response(user)


@router.post("/admins/{user_id}/mfa/reset", response_model=AdminUserResponse)
async def reset_admin_mfa(
    user_id: str,
    payload: AdminMfaResetRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    user = await AdminService(session, request.app.state.settings).reset_admin_mfa(user_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.mfa.reset",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"mfa_enabled": True},
        after_state={"mfa_enabled": False},
    )
    await session.commit()
    return admin_user_response(user)


@router.get("/users", response_model=AdminUserListResponse)
async def list_admin_users(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    role: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    query: str | None = Query(default=None, min_length=1, max_length=320),
    plan: str | None = Query(default=None),
    account_status: str | None = Query(default=None),
    email_verified: bool | None = Query(default=None),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    purchase_provider: str | None = Query(default=None),
    sort_by: str = Query(default="created_at"),
    sort_order: str = Query(default="desc"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserListResponse:
    _require_scope(principal, "admin:users:read")
    service = AdminService(session, request.app.state.settings)
    page = await service.list_users(
        limit=limit,
        cursor=cursor,
        role=role,
        is_active=is_active,
        query=query,
        plan=plan,
        account_status=account_status,
        email_verified=email_verified,
        created_from=created_from,
        created_to=created_to,
        purchase_provider=purchase_provider,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    items = [await _user_with_summary(service, item) for item in page.items]
    return AdminUserListResponse(
        items=items,
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
    )


@router.get("/users/export.csv")
async def export_admin_users_csv(
    request: Request,
    role: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    query: str | None = Query(default=None, min_length=1, max_length=320),
    plan: str | None = Query(default=None),
    account_status: str | None = Query(default=None),
    email_verified: bool | None = Query(default=None),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    purchase_provider: str | None = Query(default=None),
    sort_by: str = Query(default="created_at"),
    sort_order: str = Query(default="desc"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_scope(principal, "admin:users:read")
    service = AdminService(session, request.app.state.settings)
    page = await service.list_users(
        limit=500,
        cursor=None,
        role=role,
        is_active=is_active,
        query=query,
        plan=plan,
        account_status=account_status,
        email_verified=email_verified,
        created_from=created_from,
        created_to=created_to,
        purchase_provider=purchase_provider,
        sort_by=sort_by,
        sort_order=sort_order,
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "id",
            "email",
            "display_name",
            "role",
            "plan",
            "cloud_minutes_available",
            "status",
            "email_verified",
            "latest_purchase_provider",
            "created_at",
        ]
    )
    for user in page.items:
        summary = await _user_with_summary(service, user)
        status_value = (
            "deleted"
            if user.deletion_completed_at is not None
            else "pending_deletion"
            if user.deletion_requested_at is not None
            else "active"
            if user.is_active
            else "locked"
        )
        writer.writerow(
            [
                summary.id,
                summary.email,
                summary.display_name or "",
                summary.role,
                summary.plan or "",
                summary.cloud_minutes_available or 0,
                status_value,
                summary.email_verified_at is not None,
                summary.latest_purchase_provider or "",
                summary.created_at.isoformat(),
            ]
        )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.users.exported",
        resource_type="user_list",
        resource_id=None,
        context=_context(request),
        details={
            "rows": len(page.items),
            "truncated": page.has_more,
            "filters": {
                "role": role,
                "plan": plan,
                "account_status": account_status,
                "email_verified": email_verified,
                "purchase_provider": purchase_provider,
            },
        },
    )
    await session.commit()
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": 'attachment; filename="savestream-admin-users.csv"',
            "X-Result-Truncated": "true" if page.has_more else "false",
        },
    )


@router.get("/users/{user_id}", response_model=AdminUserResponse)
async def get_admin_user(
    user_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_scope(principal, "admin:users:read")
    return admin_user_response(
        await AdminService(session, request.app.state.settings).get_user(user_id)
    )


@router.patch("/users/{user_id}", response_model=AdminUserResponse)
async def update_admin_user(
    user_id: str,
    payload: AdminUserUpdateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_scope(principal, "admin:users:write")
    legacy_role = payload.role if principal.role == "admin" and payload.role == "admin" else None
    if payload.role is not None and legacy_role is None:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Use the owner-only admin role endpoint to change roles",
            status_code=409,
        )
    if payload.is_active is not None:
        if payload.reason is None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "A reason is required for account status changes",
                status_code=400,
            )
        await _require_step_up(
            principal=principal,
            session=session,
            request=request,
            token=step_up_token,
        )
    service = AdminService(session, request.app.state.settings)
    before = await service.get_user(user_id)
    before_state = {"role": before.role, "is_active": before.is_active}
    user = await service.update_user(
        actor_user_id=principal.user_id,
        user_id=user_id,
        role=legacy_role,
        is_active=payload.is_active,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.updated",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        before_state=before_state,
        after_state={"role": user.role, "is_active": user.is_active},
        details=payload.model_dump(exclude_none=True, exclude={"reason"}),
    )
    await session.commit()
    await session.refresh(user)
    return admin_user_response(user)


@router.get("/recordings", response_model=AdminRecordingListResponse)
async def list_admin_recordings(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    channel: str | None = Query(default=None, max_length=2048),
    status_filter: str | None = Query(default=None, alias="status"),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRecordingListResponse:
    _require_scope(principal, "admin:recordings:read")
    service = AdminRecordingService(session, request.app.state.settings)
    items, next_cursor, has_more = await service.list_recordings(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        channel=channel,
        status=status_filter,
        created_from=created_from,
        created_to=created_to,
        sort_order=sort_order,
    )
    return AdminRecordingListResponse(
        items=await _admin_recording_responses(service, items),
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.get("/recordings/export.csv")
async def export_admin_recordings_csv(
    request: Request,
    user_id: uuid.UUID | None = Query(default=None),
    channel: str | None = Query(default=None, max_length=2048),
    status_filter: str | None = Query(default=None, alias="status"),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_scope(principal, "admin:recordings:read")
    _require_scope(principal, "admin:csv:export")
    service = AdminRecordingService(session, request.app.state.settings)
    items, _, has_more = await service.list_recordings(
        limit=500,
        cursor=None,
        user_id=user_id,
        channel=channel,
        status=status_filter,
        created_from=created_from,
        created_to=created_to,
        sort_order=sort_order,
    )
    responses = await _admin_recording_responses(service, items)
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "id",
            "user_id",
            "channel",
            "status",
            "queue_position",
            "expires_at",
            "minutes_charged",
            "created_at",
        ]
    )
    for recording, response in zip(items, responses, strict=True):
        writer.writerow(
            [
                response.id,
                str(recording.user_id),
                recording.resolved_username or recording.source_value,
                response.status,
                response.queue_position or "",
                response.expires_at.isoformat() if response.expires_at else "",
                response.minutes_charged,
                response.created_at.isoformat(),
            ]
        )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.recordings.exported",
        resource_type="recording",
        resource_id=None,
        context=_context(request),
        details={"rows": len(items), "truncated": has_more},
    )
    await session.commit()
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": 'attachment; filename="savestream-admin-recordings.csv"',
            "X-Result-Truncated": "true" if has_more else "false",
        },
    )


@router.get("/recordings/{recording_id}", response_model=RecordingResponse)
async def get_admin_recording(
    recording_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RecordingResponse:
    _require_scope(principal, "admin:recordings:read")
    service = AdminRecordingService(session, request.app.state.settings)
    recording = await service.get_recording(recording_id)
    return (await _admin_recording_responses(service, [recording]))[0]


@router.post("/recordings/{recording_id}/stop", response_model=RecordingResponse)
async def stop_admin_recording(
    recording_id: str,
    payload: AdminRecordingReasonRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RecordingResponse:
    _require_scope(principal, "admin:recordings:write")
    service = AdminRecordingService(session, request.app.state.settings)
    recording, previous = await service.stop_recording(recording_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.recording.stopped",
        resource_type="recording",
        resource_id=str(recording.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"status": previous.value},
        after_state={"status": recording.status},
    )
    await session.commit()
    if previous.value == "waiting_for_cloud_slot":
        await service.wake_next(recording.user_id)
    try:
        await request.app.state.redis.client.set(
            f"savestream:recording:stop:{recording.id}",
            "1",
            ex=86400,
        )
    except Exception:
        pass
    return (await _admin_recording_responses(service, [recording]))[0]


@router.delete(
    "/recordings/{recording_id}",
    status_code=204,
    response_model=None,
)
async def delete_admin_recording(
    recording_id: str,
    payload: AdminRecordingReasonRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    _require_scope(principal, "admin:recordings:write")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = AdminRecordingService(session, request.app.state.settings)
    recording = await service.delete_recording(recording_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.recording.deleted",
        resource_type="recording",
        resource_id=str(recording.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"deleted_at": None},
        after_state={"deleted_at": recording.deleted_at.isoformat() if recording.deleted_at else None},
    )
    await session.commit()


@router.patch(
    "/recordings/{recording_id}/retention",
    response_model=RecordingResponse,
)
async def extend_admin_recording_retention(
    recording_id: str,
    payload: AdminRecordingRetentionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RecordingResponse:
    _require_scope(principal, "admin:recordings:write")
    service = AdminRecordingService(session, request.app.state.settings)
    recording, previous = await service.extend_retention(
        recording_id,
        expires_at=payload.expires_at,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.recording.retention_extended",
        resource_type="recording",
        resource_id=str(recording.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"expires_at": previous.isoformat() if previous else None},
        after_state={
            "expires_at": (
                recording.retention_expires_at.isoformat()
                if recording.retention_expires_at
                else None
            )
        },
    )
    await session.commit()
    return (await _admin_recording_responses(service, [recording]))[0]


@router.post("/recordings/{recording_id}/retry", response_model=AdminRetryRecordingResponse)
async def retry_admin_recording(
    recording_id: str,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRetryRecordingResponse:
    _require_scope(principal, "admin:recordings:write")
    original, retry = await AdminService(session, request.app.state.settings).retry_recording(
        recording_id=recording_id,
        idempotency_key=idempotency_key,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.recording.retried",
        resource_type="recording",
        resource_id=str(original.id),
        context=_context(request),
        before_state={"status": original.status},
        after_state={"retry_recording_id": str(retry.id)},
        details={"retry_recording_id": str(retry.id)},
    )
    await session.commit()
    return AdminRetryRecordingResponse(
        original_recording_id=str(original.id),
        recording=recording_response(retry),
    )


@router.post(
    "/recordings/{recording_id}/playback-access",
    response_model=AdminPlaybackAccessResponse,
)
async def request_admin_recording_playback_access(
    recording_id: str,
    payload: AdminRecordingReasonRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPlaybackAccessResponse:
    _require_scope(principal, "admin:recordings:read")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = AdminRecordingService(session, request.app.state.settings)
    recording = await service.get_recording(recording_id)
    artifact = await service.playback_artifact(recording_id)
    url = await asyncio.to_thread(
        request.app.state.minio.presigned_get_url,
        artifact.storage_key,
    )
    expires_at = datetime.now(timezone.utc) + timedelta(
        seconds=request.app.state.settings.artifact_presign_seconds
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.recording.playback_access_requested",
        resource_type="recording",
        resource_id=str(recording.id),
        context=_context(request),
        reason=payload.reason,
        details={"artifact_id": str(artifact.id)},
    )
    await session.commit()
    return AdminPlaybackAccessResponse(
        url=url,
        expires_at=expires_at,
        artifact_id=str(artifact.id),
    )


@router.get("/recording-queue", response_model=AdminQueueResponse)
async def get_admin_recording_queue(
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminQueueResponse:
    _require_scope(principal, "admin:recordings:read")
    service = AdminRecordingService(session, request.app.state.settings)
    rows, next_cursor, has_more = await service.list_waiting_queue(
        limit=limit,
        cursor=cursor,
    )
    recordings = [recording for recording, _ in rows]
    positions = await service.queue_positions(recordings)
    return AdminQueueResponse(
        items=[
            AdminQueueItemResponse(
                recording_id=str(recording.id),
                user_id=str(recording.user_id),
                user_email=email,
                channel=recording.resolved_username or recording.source_value,
                waiting_since=recording.created_at,
                queue_position=positions.get(recording.id, 1),
            )
            for recording, email in rows
        ],
        missed_today=await service.missed_today_count(),
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.get("/detector/metrics", response_model=AdminDetectorMetricsResponse)
async def get_admin_detector_metrics(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminDetectorMetricsResponse:
    _require_scope(principal, "admin:watches:read")
    metrics = await AdminRecordingService(
        session, request.app.state.settings
    ).detector_metrics()
    return AdminDetectorMetricsResponse.model_validate(metrics)


@router.get("/capacity", response_model=AdminCapacityResponse)
async def get_admin_recording_capacity(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminCapacityResponse:
    _require_scope(principal, "admin:recordings:read")
    metrics = await AdminRecordingService(
        session, request.app.state.settings
    ).capacity_metrics()
    return AdminCapacityResponse.model_validate(metrics)


@router.get("/watches/channels", response_model=AdminWatchChannelListResponse)
async def list_admin_watch_channels(
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminWatchChannelListResponse:
    _require_scope(principal, "admin:watches:read")
    items, next_cursor, has_more = await AdminRecordingService(
        session, request.app.state.settings
    ).list_watch_channels(limit=limit, cursor=cursor)
    return AdminWatchChannelListResponse(
        items=[AdminWatchChannelResponse.model_validate(item) for item in items],
        next_cursor=next_cursor,
        has_more=has_more,
    )


@router.get("/payments", response_model=AdminPaymentOrderListResponse)
async def list_admin_payments(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    channel: str | None = Query(default=None),
    package_id: uuid.UUID | None = Query(default=None),
    query: str | None = Query(default=None, max_length=160),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPaymentOrderListResponse:
    _require_scope(principal, "admin:payments:read")
    items, next_cursor, has_more = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).list_payments(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        status=status_filter,
        channel=channel,
        package_id=package_id,
        query=query,
        created_from=created_from,
        created_to=created_to,
        sort_order=sort_order,
    )
    return AdminPaymentOrderListResponse(
        items=[AdminPaymentOrderResponse.model_validate(item) for item in items],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.get("/payments/export.csv")
async def export_admin_payments(
    request: Request,
    user_id: uuid.UUID | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    channel: str | None = Query(default=None),
    package_id: uuid.UUID | None = Query(default=None),
    query: str | None = Query(default=None, max_length=160),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_scope(principal, "admin:payments:read")
    _require_scope(principal, "admin:reports:read")
    items, _, has_more = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).list_payments(
        limit=500,
        cursor=None,
        user_id=user_id,
        status=status_filter,
        channel=channel,
        package_id=package_id,
        query=query,
        created_from=created_from,
        created_to=created_to,
        sort_order=sort_order,
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "id", "user_email", "channel", "provider_transaction_id", "package",
        "status", "credits", "gross_usd_minor", "estimated_store_fee_minor",
        "created_at",
    ])
    for item in items:
        writer.writerow([
            item["id"], item["user_email"], item["purchase_channel"],
            item["provider_transaction_id"] or "", item["package_code"],
            item["status"], item["credits"], item["gross_usd_minor"] or "",
            item["estimated_store_fee_minor"] or "", str(item["created_at"]),
        ])
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.payments.exported",
        resource_type="payment_order",
        resource_id=None,
        context=_context(request),
        details={"rows": len(items), "truncated": has_more},
    )
    await session.commit()
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": 'attachment; filename="savestream-admin-payments.csv"',
            "X-Result-Truncated": "true" if has_more else "false",
        },
    )


@router.get("/payments/stuck", response_model=AdminStuckPaymentListResponse)
async def list_admin_stuck_payments(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStuckPaymentListResponse:
    _require_scope(principal, "admin:payments:read")
    items, next_cursor, has_more = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).stuck_payments(limit=limit, cursor=cursor)
    return AdminStuckPaymentListResponse(
        items=[AdminStuckPaymentResponse.model_validate(item) for item in items],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.get(
    "/payments/{payment_order_id}",
    response_model=AdminPaymentOrderDetailResponse,
)
async def get_admin_payment(
    payment_order_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPaymentOrderDetailResponse:
    _require_scope(principal, "admin:payments:read")
    detail = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).payment_detail(payment_order_id)
    return AdminPaymentOrderDetailResponse.model_validate(detail)


@router.get(
    "/payments/{payment_order_id}/refund-preview",
    response_model=AdminRefundPreviewResponse,
)
async def preview_admin_refund(
    payment_order_id: str,
    request: Request,
    amount_minor: int = Query(gt=0),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRefundPreviewResponse:
    _require_scope(principal, "admin:payments:refund")
    preview = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).refund_preview(payment_order_id, amount_minor)
    return AdminRefundPreviewResponse.model_validate(preview)


@router.post(
    "/payments/{payment_order_id}/reconcile",
    response_model=AdminReconcilePaymentResponse,
)
async def reconcile_admin_payment(
    payment_order_id: str,
    payload: AdminReasonRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminReconcilePaymentResponse:
    _require_scope(principal, "admin:payments:refund")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    result = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).reconcile_payment(payment_order_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.payment.reconciled",
        resource_type="payment_order",
        resource_id=payment_order_id,
        context=_context(request),
        reason=payload.reason,
        after_state={"action": result["action"], "status": result["status"]},
    )
    await session.commit()
    return AdminReconcilePaymentResponse.model_validate(result)


@router.get("/credits/ledger", response_model=AdminLedgerListResponse)
async def list_admin_credit_ledger(
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    category: str | None = Query(default=None),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminLedgerListResponse:
    _require_scope(principal, "admin:credits:read")
    items, next_cursor, has_more = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).list_ledger(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        category=category,
        created_from=created_from,
        created_to=created_to,
        sort_order=sort_order,
    )
    return AdminLedgerListResponse(
        items=[AdminLedgerEntryResponse.model_validate(item) for item in items],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.get("/credits/ledger/export.csv")
async def export_admin_credit_ledger(
    request: Request,
    user_id: uuid.UUID | None = Query(default=None),
    category: str | None = Query(default=None),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_scope(principal, "admin:credits:read")
    _require_scope(principal, "admin:reports:read")
    items, _, has_more = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).list_ledger(
        limit=500,
        cursor=None,
        user_id=user_id,
        category=category,
        created_from=created_from,
        created_to=created_to,
        sort_order=sort_order,
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "id", "user_email", "category", "type", "amount", "balance_after",
        "reference_type", "reference_id", "counts_as_purchase", "created_at",
    ])
    for item in items:
        writer.writerow([
            item["id"], item["user_email"], item["category"], item["type"],
            item["amount"], item["balance_after"], item["reference_type"],
            item["reference_id"] or "", item["counts_as_purchase"],
            str(item["created_at"]),
        ])
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.credits.ledger_exported",
        resource_type="credit_ledger",
        resource_id=None,
        context=_context(request),
        details={"rows": len(items), "truncated": has_more},
    )
    await session.commit()
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": 'attachment; filename="savestream-admin-credit-ledger.csv"',
            "X-Result-Truncated": "true" if has_more else "false",
        },
    )


@router.get(
    "/credits/stuck-reservations",
    response_model=AdminStuckReservationListResponse,
)
async def list_admin_stuck_reservations(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStuckReservationListResponse:
    _require_scope(principal, "admin:credits:read")
    items, next_cursor, has_more = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).stuck_reservations(limit=limit, cursor=cursor)
    return AdminStuckReservationListResponse(
        items=[AdminStuckReservationResponse.model_validate(item) for item in items],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.post(
    "/credits/stuck-reservations/{reservation_id}/release",
    response_model=AdminReservationReleaseResponse,
)
async def release_admin_stuck_reservation(
    reservation_id: str,
    payload: AdminReasonRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminReservationReleaseResponse:
    _require_scope(principal, "admin:credits:adjust")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    reservation, released = await AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    ).release_stuck_reservation(reservation_id, reason=payload.reason)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.credit.reservation_released",
        resource_type="credit_reservation",
        resource_id=reservation_id,
        context=_context(request),
        reason=payload.reason,
        after_state={"released_credits": released},
    )
    await session.commit()
    return AdminReservationReleaseResponse(
        reservation=AdminStuckReservationResponse.model_validate(reservation),
        released_credits=released,
    )


@router.post("/payments/{payment_order_id}/refunds", response_model=AdminRefundResponse)
async def refund_admin_payment(
    payment_order_id: str,
    payload: AdminRefundRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRefundResponse:
    _require_scope(principal, "admin:payments:refund")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    finance = AdminFinanceService(
        session, selected_payment_provider(request.app.state.settings)
    )
    preview = await finance.refund_preview(payment_order_id, payload.amount_minor)
    if payload.credits != preview["corresponding_credits"]:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Refund credits must match the proportional refund preview",
            status_code=409,
            details={"expected_credits": preview["corresponding_credits"]},
        )
    refund = await BillingAdminService(
        session,
        selected_payment_provider(request.app.state.settings),
    ).request_refund(
        payment_order_id=payment_order_id,
        amount_minor=payload.amount_minor,
        credits=payload.credits,
        idempotency_key=idempotency_key,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.payment.refund_requested",
        resource_type="payment_order",
        resource_id=payment_order_id,
        context=_context(request),
        reason=payload.reason,
        after_state={
            "refund_id": str(refund.id),
            "amount_minor": payload.amount_minor,
            "credits": payload.credits,
        },
    )
    await session.commit()
    return AdminRefundResponse(
        id=str(refund.id),
        payment_order_id=str(refund.payment_order_id),
        status=refund.status,
        credits=refund.credits,
        amount_minor=refund.amount_minor,
        provider=refund.provider,
        provider_refund_reference=refund.provider_refund_reference,
        created_at=refund.created_at,
    )


@router.post("/credits/adjustments", response_model=AdminCreditAdjustmentResponse)
async def adjust_admin_credit(
    payload: AdminCreditAdjustmentRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminCreditAdjustmentResponse:
    _require_scope(principal, "admin:credits:adjust")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    try:
        user_id = uuid.UUID(payload.user_id)
    except ValueError as exc:
        raise ApplicationError("RESOURCE_NOT_FOUND", "User not found", status_code=404) from exc
    transaction = await CreditAdminService(session).adjust(
        user_id=user_id,
        amount=payload.amount,
        idempotency_key=idempotency_key,
        reason=payload.reason,
        counts_as_purchase=payload.counts_as_purchase,
        commit=False,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.credit.adjusted",
        resource_type="user",
        resource_id=str(user_id),
        context=_context(request),
        reason=payload.reason,
        after_state={
            "transaction_id": str(transaction.id),
            "amount": payload.amount,
            "counts_as_purchase": payload.counts_as_purchase,
        },
    )
    await session.commit()
    return AdminCreditAdjustmentResponse(transaction=transaction_response(transaction))


@router.get("/audit", response_model=AuditLogListResponse)
async def list_admin_audit(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    actor_user_id: uuid.UUID | None = Query(default=None),
    resource_type: str | None = Query(default=None),
    action: str | None = Query(default=None),
    created_from: datetime | None = Query(default=None),
    created_to: datetime | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AuditLogListResponse:
    _require_scope(principal, "admin:audit:read")
    page = await AuditService(session).list(
        limit=limit,
        cursor=cursor,
        actor_user_id=actor_user_id,
        resource_type=resource_type,
        action=action,
        created_from=created_from,
        created_to=created_to,
    )
    return AuditLogListResponse(
        items=[audit_log_response(item) for item in page.items],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
    )



@router.get("/users/{user_id}/detail", response_model=AdminUserDetailResponse)
async def get_admin_user_detail(
    user_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserDetailResponse:
    _require_scope(principal, "admin:users:read")
    service = AdminService(session, request.app.state.settings)
    data = await service.get_user_detail(user_id)
    user_response = admin_user_response(
        data.user,
        plan=data.entitlement.plan,
        cloud_minutes_available=data.balance.available,
        latest_purchase_provider=data.latest_purchase_provider,
    )
    return AdminUserDetailResponse(
        user=user_response,
        entitlement=_entitlement_response(data.entitlement),
        balance=CreditBalanceResponse(
            posted=data.balance.posted,
            reserved=data.balance.reserved,
            available=data.balance.available,
        ),
        watches=[
            watch_response(
                item,
                is_pro=data.entitlement.is_pro,
                has_purchased=data.entitlement.has_purchased,
            )
            for item in data.watches
        ],
        recordings=[recording_response(item) for item in data.recordings],
        payments=[payment_order_response(item) for item in data.payments],
        ledger=[transaction_response(item) for item in data.ledger],
        sessions=[
            AdminUserSessionResponse(
                id=str(item.id),
                client_type=item.client_type,
                user_agent=item.user_agent,
                ip_hint=ip_hint(item.ip_address),
                created_at=item.created_at,
                last_seen_at=item.last_seen_at,
                expires_at=item.expires_at,
                revoked_at=item.revoked_at,
                revoked_reason=item.revoked_reason,
            )
            for item in data.sessions
        ],
        notifications=[
            AdminUserNotificationResponse(
                id=str(item.id),
                kind=item.kind,
                title=item.title,
                body=item.body,
                resource_type=item.resource_type,
                resource_id=item.resource_id,
                read_at=item.read_at,
                created_at=item.created_at,
            )
            for item in data.notifications
        ],
        notes=[
            AdminUserNoteResponse(
                id=str(item.id),
                user_id=str(item.user_id),
                author_user_id=str(item.author_user_id) if item.author_user_id else None,
                body=item.body,
                created_at=item.created_at,
                updated_at=item.updated_at,
            )
            for item in data.notes
        ],
        audit=[audit_log_response(item) for item in data.audit],
    )


@router.post(
    "/users/{user_id}/resend-verification",
    response_model=AdminActionResponse,
)
async def resend_admin_user_verification(
    user_id: str,
    payload: AdminSupportActionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminActionResponse:
    _require_scope(principal, "admin:users:write")
    user = await AdminService(session, request.app.state.settings).issue_identity_token(
        user_id, "verify_email"
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.verification_resent",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
    )
    await session.commit()
    return AdminActionResponse(message="Verification email queued")


@router.post(
    "/users/{user_id}/force-password-reset",
    response_model=AdminActionResponse,
)
async def force_admin_user_password_reset(
    user_id: str,
    payload: AdminSupportActionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminActionResponse:
    _require_scope(principal, "admin:users:write")
    user = await AdminService(session, request.app.state.settings).issue_identity_token(
        user_id, "password_reset"
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.password_reset_forced",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
    )
    await session.commit()
    return AdminActionResponse(message="Password reset email queued")


@router.post("/users/{user_id}/force-logout", response_model=AdminActionResponse)
async def force_admin_user_logout(
    user_id: str,
    payload: AdminSupportActionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminActionResponse:
    _require_scope(principal, "admin:users:write")
    user = await AdminService(session, request.app.state.settings).force_logout(user_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.force_logout",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
    )
    await session.commit()
    return AdminActionResponse(message="All user sessions revoked")


@router.patch("/users/{user_id}/profile", response_model=AdminUserResponse)
async def update_admin_user_profile(
    user_id: str,
    payload: AdminUserProfileUpdateRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_scope(principal, "admin:users:write")
    service = AdminService(session, request.app.state.settings)
    user, previous = await service.update_display_name(user_id, payload.display_name)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.profile_updated",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"display_name": previous},
        after_state={"display_name": user.display_name},
    )
    await session.commit()
    return await _user_with_summary(service, user)


@router.post("/users/{user_id}/notes", response_model=AdminUserNoteResponse)
async def create_admin_user_note(
    user_id: str,
    payload: AdminUserNoteRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserNoteResponse:
    _require_scope(principal, "admin:users:write")
    note = await AdminService(session, request.app.state.settings).create_user_note(
        actor_user_id=principal.user_id,
        user_id=user_id,
        body=payload.body,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.note_created",
        resource_type="user",
        resource_id=user_id,
        context=_context(request),
        reason=payload.reason,
        after_state={"note_id": str(note.id)},
    )
    await session.commit()
    await session.refresh(note)
    return AdminUserNoteResponse(
        id=str(note.id),
        user_id=str(note.user_id),
        author_user_id=str(note.author_user_id) if note.author_user_id else None,
        body=note.body,
        created_at=note.created_at,
        updated_at=note.updated_at,
    )


@router.patch(
    "/users/{user_id}/notes/{note_id}",
    response_model=AdminUserNoteResponse,
)
async def update_admin_user_note(
    user_id: str,
    note_id: str,
    payload: AdminUserNoteRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserNoteResponse:
    _require_scope(principal, "admin:users:write")
    service = AdminService(session, request.app.state.settings)
    existing = await service.update_user_note(
        actor_user_id=principal.user_id,
        user_id=user_id,
        note_id=note_id,
        body=payload.body,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.note_updated",
        resource_type="user",
        resource_id=user_id,
        context=_context(request),
        reason=payload.reason,
        after_state={"note_id": str(existing.id)},
    )
    await session.commit()
    return AdminUserNoteResponse(
        id=str(existing.id),
        user_id=str(existing.user_id),
        author_user_id=str(existing.author_user_id) if existing.author_user_id else None,
        body=existing.body,
        created_at=existing.created_at,
        updated_at=existing.updated_at,
    )


@router.get("/search", response_model=AdminSearchResponse)
async def search_admin(
    request: Request,
    q: str = Query(min_length=2, max_length=320),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminSearchResponse:
    _require_scope(principal, "admin:users:read")
    hits = await AdminService(session, request.app.state.settings).global_search(q)
    return AdminSearchResponse(items=[AdminSearchHit.model_validate(item) for item in hits])


@router.get("/privacy/requests", response_model=AdminPrivacyRequestListResponse)
async def list_admin_privacy_requests(
    request: Request,
    limit: int = Query(default=100, ge=1, le=200),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPrivacyRequestListResponse:
    _require_scope(principal, "admin:users:read")
    rows = await AdminService(session, request.app.state.settings).list_privacy_requests(limit=limit)
    return AdminPrivacyRequestListResponse(
        items=[AdminPrivacyRequestResponse.model_validate(item) for item in rows]
    )


@router.post("/users/{user_id}/privacy/export")
async def export_admin_user_privacy_data(
    user_id: str,
    payload: AdminSupportActionRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> JSONResponse:
    _require_scope(principal, "admin:users:read")
    user = await AdminService(session, request.app.state.settings).get_user(user_id)
    exported = await PrivacyService(session).export_user(user.id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.privacy_exported",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        details={"schema_version": exported.get("schema_version")},
    )
    await session.commit()
    return JSONResponse(
        content=jsonable_encoder(exported),
        headers={
            "Content-Disposition": f'attachment; filename="savestream-user-{user.id}-export.json"',
            "Cache-Control": "no-store",
        },
    )


@router.post(
    "/users/{user_id}/privacy/deletion/cancel",
    response_model=AdminActionResponse,
)
async def cancel_admin_user_deletion(
    user_id: str,
    payload: AdminSupportActionRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminActionResponse:
    _require_scope(principal, "admin:users:write")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    user = await AdminService(session, request.app.state.settings).cancel_deletion(user_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.deletion_cancelled",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        before_state={"deletion_requested": True, "is_active": False},
        after_state={"deletion_requested": False, "is_active": True},
    )
    await session.commit()
    return AdminActionResponse(message="Deletion request cancelled")


@router.post(
    "/users/{user_id}/privacy/deletion/perform",
    response_model=AdminActionResponse,
)
async def perform_admin_user_deletion(
    user_id: str,
    payload: AdminSupportActionRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminActionResponse:
    _require_scope(principal, "admin:users:write")
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = AdminService(session, request.app.state.settings)
    user = await service.get_user(user_id)
    if user.deletion_requested_at is None or user.deletion_completed_at is not None:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "User does not have a pending deletion request",
            status_code=409,
        )
    before = {
        "email": user.email,
        "deletion_requested_at": user.deletion_requested_at.isoformat(),
    }
    completed = await PrivacyService(session).anonymize_user(user.id)
    if not completed:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Deletion request could not be completed",
            status_code=409,
        )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.deletion_performed",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        reason=payload.reason,
        before_state=before,
        after_state={"deletion_completed": True, "is_active": False},
    )
    await session.commit()
    return AdminActionResponse(message="Account deletion completed")


@router.get("/users/{user_id}/view", response_model=AdminViewAsUserResponse)
async def view_as_admin_user(
    user_id: str,
    request: Request,
    reason: str = Query(min_length=3, max_length=500),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminViewAsUserResponse:
    _require_scope(principal, "admin:users:read")
    service = AdminService(session, request.app.state.settings)
    data = await service.get_user_detail(user_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.user.viewed_as",
        resource_type="user",
        resource_id=str(data.user.id),
        context=_context(request),
        reason=reason,
        details={"read_only": True},
    )
    await session.commit()
    return AdminViewAsUserResponse(
        user=admin_user_response(
            data.user,
            plan=data.entitlement.plan,
            cloud_minutes_available=data.balance.available,
            latest_purchase_provider=data.latest_purchase_provider,
        ),
        entitlement=_entitlement_response(data.entitlement),
        balance=CreditBalanceResponse(
            posted=data.balance.posted,
            reserved=data.balance.reserved,
            available=data.balance.available,
        ),
        watches=[
            watch_response(
                item,
                is_pro=data.entitlement.is_pro,
                has_purchased=data.entitlement.has_purchased,
            )
            for item in data.watches
        ],
        recordings=[recording_response(item) for item in data.recordings],
    )



def _d7_storage_run_response(run) -> AdminStorageRunResponse:
    details = run.details if isinstance(run.details, dict) else {}
    return AdminStorageRunResponse(
        id=str(run.id),
        kind=run.kind,
        status=run.status,
        scanned_count=run.scanned_count,
        orphan_count=run.orphan_count,
        deleted_count=run.deleted_count,
        orphan_keys=[str(item) for item in details.get("orphan_keys", [])],
        truncated=bool(details.get("truncated", False)),
        error=run.error,
        created_at=run.created_at,
        started_at=run.started_at,
        completed_at=run.completed_at,
    )


def _d7_email_log_response(row) -> AdminEmailLogResponse:
    return AdminEmailLogResponse(
        id=str(row.id),
        user_id=str(row.user_id) if row.user_id else None,
        recipient_email=row.recipient_email,
        kind=row.kind,
        subject=row.subject,
        status=row.status,
        error=row.error,
        attempts=row.attempts,
        sent_at=row.sent_at,
        created_at=row.created_at,
    )


def _d7_broadcast_response(row) -> AdminBroadcastResponse:
    return AdminBroadcastResponse(
        id=str(row.id),
        kind=row.kind,
        title=row.title,
        body=row.body,
        channels=list(row.channels),
        status=row.status,
        audience_count=row.audience_count,
        delivered_in_app=row.delivered_in_app,
        delivered_push=row.delivered_push,
        delivered_email=row.delivered_email,
        failed_count=row.failed_count,
        reason=row.reason,
        created_at=row.created_at,
        started_at=row.started_at,
        completed_at=row.completed_at,
    )


@router.get("/storage/summary", response_model=AdminStorageSummaryResponse)
async def get_admin_storage_summary(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStorageSummaryResponse:
    _require_scope(principal, "admin:operations:read")
    summary = await AdminOperationsService(
        session, request.app.state.settings
    ).storage_summary()
    return AdminStorageSummaryResponse.model_validate(summary)


@router.post("/storage/orphan-scans", response_model=AdminStorageRunResponse)
async def create_admin_orphan_scan(
    payload: AdminOrphanScanRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStorageRunResponse:
    _require_owner(principal)
    run = await AdminOperationsService(
        session, request.app.state.settings
    ).create_orphan_scan(actor_user_id=principal.user_id, limit=payload.limit)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.storage.orphan_scan_queued",
        resource_type="admin_storage_run",
        resource_id=str(run.id),
        context=_context(request),
        reason=payload.reason,
        details={"limit": payload.limit},
    )
    await session.commit()
    return _d7_storage_run_response(run)


@router.get("/storage/runs/{run_id}", response_model=AdminStorageRunResponse)
async def get_admin_storage_run(
    run_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStorageRunResponse:
    _require_owner(principal)
    run = await AdminOperationsService(
        session, request.app.state.settings
    ).get_storage_run(run_id)
    return _d7_storage_run_response(run)


@router.post("/storage/orphan-scans/{run_id}/delete", response_model=AdminStorageRunResponse)
async def delete_admin_orphan_files(
    run_id: str,
    payload: AdminReasonRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminStorageRunResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    run = await AdminOperationsService(
        session, request.app.state.settings
    ).create_orphan_delete(actor_user_id=principal.user_id, source_run_id=run_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.storage.orphans_delete_queued",
        resource_type="admin_storage_run",
        resource_id=str(run.id),
        context=_context(request),
        reason=payload.reason,
        details={"source_run_id": run_id, "orphan_count": run.orphan_count},
    )
    await session.commit()
    return _d7_storage_run_response(run)


@router.get("/email/logs", response_model=AdminEmailLogListResponse)
async def list_admin_email_logs(
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    recipient: str | None = Query(default=None),
    kind: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminEmailLogListResponse:
    _require_scope(principal, "admin:users:write")
    items, next_cursor, has_more = await AdminOperationsService(
        session, request.app.state.settings
    ).list_email_logs(
        limit=limit,
        cursor=cursor,
        recipient=recipient,
        kind=kind,
        status=status_filter,
        sort_order=sort_order,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.email.logs_viewed",
        resource_type="email_log",
        resource_id=None,
        context=_context(request),
        details={"rows": len(items), "recipient": recipient, "kind": kind, "status": status_filter},
    )
    await session.commit()
    return AdminEmailLogListResponse(
        items=[_d7_email_log_response(item) for item in items],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.get("/email/logs/export.csv")
async def export_admin_email_logs(
    request: Request,
    recipient: str | None = Query(default=None),
    kind: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_scope(principal, "admin:users:write")
    _require_scope(principal, "admin:csv:export")
    items, _, has_more = await AdminOperationsService(
        session, request.app.state.settings
    ).list_email_logs(
        limit=500,
        cursor=None,
        recipient=recipient,
        kind=kind,
        status=status_filter,
        sort_order=sort_order,
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "recipient_email", "kind", "subject", "status", "attempts", "sent_at", "created_at"])
    for item in items:
        writer.writerow([
            str(item.id),
            item.recipient_email,
            item.kind,
            item.subject,
            item.status,
            item.attempts,
            item.sent_at.isoformat() if item.sent_at else "",
            item.created_at.isoformat(),
        ])
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.email.logs_exported",
        resource_type="email_log",
        resource_id=None,
        context=_context(request),
        details={"rows": len(items), "truncated": has_more},
    )
    await session.commit()
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": 'attachment; filename="savestream-admin-email-logs.csv"',
            "X-Result-Truncated": "true" if has_more else "false",
        },
    )


@router.post("/email/logs/{log_id}/resend", response_model=AdminEmailLogResponse)
async def resend_admin_email(
    log_id: str,
    payload: AdminReasonRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminEmailLogResponse:
    _require_scope(principal, "admin:users:write")
    log = await AdminOperationsService(
        session, request.app.state.settings
    ).resend_email(log_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.email.resent",
        resource_type="email_log",
        resource_id=str(log.id),
        context=_context(request),
        reason=payload.reason,
        details={"kind": log.kind, "recipient": log.recipient_email},
    )
    await session.commit()
    return _d7_email_log_response(log)


@router.get("/email/templates", response_model=list[AdminEmailTemplateResponse])
async def list_admin_email_templates(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> list[AdminEmailTemplateResponse]:
    _require_owner(principal)
    rows = await AdminOperationsService(
        session, request.app.state.settings
    ).email_templates()
    return [AdminEmailTemplateResponse.model_validate(item) for item in rows]


@router.get("/email/templates/{key}/preview", response_model=AdminEmailPreviewResponse)
async def preview_admin_email_template(
    key: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminEmailPreviewResponse:
    _require_owner(principal)
    rendered = await AdminOperationsService(
        session, request.app.state.settings
    ).preview_email_template(key)
    return AdminEmailPreviewResponse(
        subject=rendered.subject,
        text=rendered.text,
        html=rendered.html,
    )


@router.put("/email/templates/{key}", response_model=AdminEmailTemplateResponse)
async def update_admin_email_template(
    key: str,
    payload: AdminEmailTemplateUpdateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminEmailTemplateResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = AdminOperationsService(session, request.app.state.settings)
    before_rows = {item["key"]: item for item in await service.email_templates()}
    row = await service.update_email_template(
        key=key,
        subject=payload.subject,
        body=payload.body,
        actor_user_id=principal.user_id,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.email.template_updated",
        resource_type="email_template",
        resource_id=key,
        context=_context(request),
        reason=payload.reason,
        before_state={
            "subject": before_rows.get(key, {}).get("subject"),
            "body": before_rows.get(key, {}).get("body"),
        },
        after_state={"subject": row.subject, "body": row.body},
    )
    await session.commit()
    await session.refresh(row)
    return AdminEmailTemplateResponse.model_validate(
        {
            "key": key,
            "subject": row.subject,
            "body": row.body,
            "overridden": True,
            "updated_at": row.updated_at,
        }
    )


@router.delete("/email/templates/{key}", response_model=AdminActionResponse)
async def reset_admin_email_template(
    key: str,
    payload: AdminReasonRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminActionResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = AdminOperationsService(session, request.app.state.settings)
    await service.reset_email_template(key)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.email.template_reset",
        resource_type="email_template",
        resource_id=key,
        context=_context(request),
        reason=payload.reason,
    )
    await session.commit()
    return AdminActionResponse(message="Email template reset to default")


@router.post("/email/templates/{key}/test", response_model=AdminEmailLogResponse)
async def test_admin_email_template(
    key: str,
    payload: AdminEmailTestRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminEmailLogResponse:
    _require_owner(principal)
    log = await AdminOperationsService(
        session, request.app.state.settings
    ).send_template_test(key=key, actor_user_id=principal.user_id)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.email.template_tested",
        resource_type="email_template",
        resource_id=key,
        context=_context(request),
        reason=payload.reason,
        details={"recipient": log.recipient_email},
    )
    await session.commit()
    return _d7_email_log_response(log)


@router.post("/broadcasts/preview", response_model=AdminBroadcastPreviewResponse)
async def preview_admin_broadcast(
    payload: AdminBroadcastPreviewRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBroadcastPreviewResponse:
    _require_owner(principal)
    count = await AdminOperationsService(
        session, request.app.state.settings
    ).audience_count(payload.kind)
    return AdminBroadcastPreviewResponse(
        audience_count=count,
        kind=payload.kind,
        channels=payload.channels,
    )


@router.get("/broadcasts", response_model=AdminBroadcastListResponse)
async def list_admin_broadcasts(
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    kind: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    query: str | None = Query(default=None, max_length=160),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBroadcastListResponse:
    _require_owner(principal)
    items, next_cursor, has_more = await AdminOperationsService(
        session, request.app.state.settings
    ).list_broadcasts(
        limit=limit,
        cursor=cursor,
        kind=kind,
        status=status_filter,
        query=query,
        sort_order=sort_order,
    )
    return AdminBroadcastListResponse(
        items=[_d7_broadcast_response(item) for item in items],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )


@router.get("/broadcasts/export.csv")
async def export_admin_broadcasts(
    request: Request,
    kind: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    query: str | None = Query(default=None, max_length=160),
    sort_order: str = Query(default="desc", pattern="^(asc|desc)$"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    _require_owner(principal)
    items, _, has_more = await AdminOperationsService(
        session, request.app.state.settings
    ).list_broadcasts(
        limit=500,
        cursor=None,
        kind=kind,
        status=status_filter,
        query=query,
        sort_order=sort_order,
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "id", "kind", "title", "channels", "status", "audience_count",
        "delivered_in_app", "delivered_push", "delivered_email", "failed_count", "created_at",
    ])
    for item in items:
        writer.writerow([
            str(item.id), item.kind, item.title, ",".join(item.channels), item.status,
            item.audience_count, item.delivered_in_app, item.delivered_push,
            item.delivered_email, item.failed_count, item.created_at.isoformat(),
        ])
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.broadcasts.exported",
        resource_type="admin_broadcast",
        resource_id=None,
        context=_context(request),
        details={"rows": len(items), "truncated": has_more},
    )
    await session.commit()
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": 'attachment; filename="savestream-admin-broadcasts.csv"',
            "X-Result-Truncated": "true" if has_more else "false",
        },
    )


@router.get("/broadcasts/{broadcast_id}", response_model=AdminBroadcastResponse)
async def get_admin_broadcast(
    broadcast_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBroadcastResponse:
    _require_owner(principal)
    row = await AdminOperationsService(
        session, request.app.state.settings
    ).get_broadcast(broadcast_id)
    return _d7_broadcast_response(row)


@router.post("/broadcasts", response_model=AdminBroadcastResponse)
async def create_admin_broadcast(
    payload: AdminBroadcastCreateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBroadcastResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    row = await AdminOperationsService(
        session, request.app.state.settings
    ).create_broadcast(
        actor_user_id=principal.user_id,
        kind=payload.kind,
        title=payload.title,
        body=payload.body,
        channels=payload.channels,
        reason=payload.reason,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.broadcast.queued",
        resource_type="admin_broadcast",
        resource_id=str(row.id),
        context=_context(request),
        reason=payload.reason,
        after_state={
            "kind": row.kind,
            "channels": row.channels,
            "audience_count": row.audience_count,
        },
    )
    await session.commit()
    return _d7_broadcast_response(row)


@router.get("/packages", response_model=AdminPackageListResponse)
async def list_admin_packages(
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPackageListResponse:
    _require_scope(principal, "admin:packages:read")
    items = await AdminCatalogService(session).packages()
    return AdminPackageListResponse(
        items=[AdminPackageResponse.model_validate(item) for item in items]
    )


@router.post("/packages", response_model=AdminPackageResponse)
async def create_admin_package(
    payload: AdminPackageCreateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPackageResponse:
    _require_scope(principal, "admin:packages:write")
    await _require_step_up(
        principal=principal, session=session, request=request, token=step_up_token
    )
    item = await AdminCatalogService(session).create_package(
        code=payload.code,
        name=payload.name,
        credits=payload.credits,
        amount_minor=payload.amount_minor,
        display_order=payload.display_order,
        app_store_product_id=payload.app_store_product_id,
        google_play_product_id=payload.google_play_product_id,
        web_variant_id=payload.web_variant_id,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.package.created",
        resource_type="credit_package",
        resource_id=str(item["id"]),
        context=_context(request),
        reason=payload.reason,
        after_state=item,
    )
    await session.commit()
    return AdminPackageResponse.model_validate(item)


@router.patch("/packages/{package_id}", response_model=AdminPackageResponse)
async def update_admin_package(
    package_id: str,
    payload: AdminPackageUpdateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPackageResponse:
    _require_scope(principal, "admin:packages:write")
    await _require_step_up(
        principal=principal, session=session, request=request, token=step_up_token
    )
    before, item = await AdminCatalogService(session).update_package(
        package_id,
        name=payload.name,
        credits=payload.credits,
        amount_minor=payload.amount_minor,
        display_order=payload.display_order,
        active=payload.active,
        app_store_product_id=payload.app_store_product_id,
        google_play_product_id=payload.google_play_product_id,
        web_variant_id=payload.web_variant_id,
        clear_app_store_product_id=payload.clear_app_store_product_id,
        clear_google_play_product_id=payload.clear_google_play_product_id,
        clear_web_variant_id=payload.clear_web_variant_id,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.package.updated",
        resource_type="credit_package",
        resource_id=package_id,
        context=_context(request),
        reason=payload.reason,
        before_state=before,
        after_state=item,
    )
    await session.commit()
    return AdminPackageResponse.model_validate(item)


@router.get("/promotions", response_model=AdminPromotionListResponse)
async def list_admin_promotions(
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPromotionListResponse:
    _require_scope(principal, "admin:promotions:read")
    items = await AdminCatalogService(session).promotions()
    return AdminPromotionListResponse(
        items=[AdminPromotionResponse.model_validate(item) for item in items]
    )


@router.post("/promotions", response_model=AdminPromotionResponse)
async def create_admin_promotion(
    payload: AdminPromotionCreateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPromotionResponse:
    _require_scope(principal, "admin:promotions:write")
    await _require_step_up(
        principal=principal, session=session, request=request, token=step_up_token
    )
    item = await AdminCatalogService(session).create_promotion(
        actor_user_id=principal.user_id,
        code=payload.code,
        credits=payload.credits,
        expires_at=payload.expires_at,
        max_redemptions=payload.max_redemptions,
        counts_as_purchase=payload.counts_as_purchase,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.promotion.created",
        resource_type="promotion_code",
        resource_id=str(item["id"]),
        context=_context(request),
        reason=payload.reason,
        after_state=item,
    )
    await session.commit()
    return AdminPromotionResponse.model_validate(item)


@router.patch("/promotions/{promotion_id}", response_model=AdminPromotionResponse)
async def update_admin_promotion(
    promotion_id: str,
    payload: AdminPromotionUpdateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPromotionResponse:
    _require_scope(principal, "admin:promotions:write")
    await _require_step_up(
        principal=principal, session=session, request=request, token=step_up_token
    )
    before, item = await AdminCatalogService(session).update_promotion(
        promotion_id,
        credits=payload.credits,
        expires_at=payload.expires_at,
        clear_expires_at=payload.clear_expires_at,
        max_redemptions=payload.max_redemptions,
        clear_max_redemptions=payload.clear_max_redemptions,
        active=payload.active,
        counts_as_purchase=payload.counts_as_purchase,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.promotion.updated",
        resource_type="promotion_code",
        resource_id=promotion_id,
        context=_context(request),
        reason=payload.reason,
        before_state=before,
        after_state=item,
    )
    await session.commit()
    return AdminPromotionResponse.model_validate(item)


@router.get(
    "/promotions/{promotion_id}/redemptions",
    response_model=AdminPromotionRedemptionListResponse,
)
async def list_admin_promotion_redemptions(
    promotion_id: str,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPromotionRedemptionListResponse:
    _require_scope(principal, "admin:promotions:read")
    items, next_cursor, has_more = await AdminCatalogService(
        session
    ).promotion_redemptions(promotion_id, limit=limit, cursor=cursor)
    return AdminPromotionRedemptionListResponse(
        items=[
            AdminPromotionRedemptionResponse.model_validate(item)
            for item in items
        ],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )



@router.post(
    "/bulk-grants/preview",
    response_model=AdminBulkGrantPreviewResponse,
)
async def preview_admin_bulk_grant(
    payload: AdminBulkGrantPreviewRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBulkGrantPreviewResponse:
    _require_scope(principal, "admin:credits:adjust")
    result = await AdminBulkGrantService(
        session, request.app.state.settings
    ).preview(
        credits=payload.credits,
        filters=payload.filters.model_dump(mode="json", exclude_none=True),
    )
    return AdminBulkGrantPreviewResponse.model_validate(result)


@router.post("/bulk-grants", response_model=AdminBulkGrantResponse)
async def create_admin_bulk_grant(
    payload: AdminBulkGrantCreateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBulkGrantResponse:
    _require_scope(principal, "admin:credits:adjust")
    await _require_step_up(
        principal=principal, session=session, request=request, token=step_up_token
    )
    grant = await AdminBulkGrantService(
        session, request.app.state.settings
    ).create(
        actor_user_id=principal.user_id,
        credits=payload.credits,
        counts_as_purchase=payload.counts_as_purchase,
        reason=payload.reason,
        filters=payload.filters.model_dump(mode="json", exclude_none=True),
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.bulk_grant.queued",
        resource_type="admin_bulk_grant",
        resource_id=str(grant.id),
        context=_context(request),
        reason=payload.reason,
        after_state={
            "credits": grant.credits,
            "counts_as_purchase": grant.counts_as_purchase,
            "audience_count": grant.audience_count,
            "total_credits": grant.total_credits,
            "filters": grant.filters,
        },
    )
    await session.commit()
    return AdminBulkGrantResponse.model_validate(
        AdminBulkGrantService.payload(grant)
    )


@router.get("/bulk-grants/{grant_id}", response_model=AdminBulkGrantResponse)
async def get_admin_bulk_grant(
    grant_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBulkGrantResponse:
    _require_scope(principal, "admin:credits:read")
    grant = await AdminBulkGrantService(
        session, request.app.state.settings
    ).get(grant_id)
    return AdminBulkGrantResponse.model_validate(
        AdminBulkGrantService.payload(grant)
    )


@router.get(
    "/bulk-grants/{grant_id}/deliveries",
    response_model=AdminBulkGrantDeliveryListResponse,
)
async def list_admin_bulk_grant_deliveries(
    grant_id: str,
    request: Request,
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminBulkGrantDeliveryListResponse:
    _require_scope(principal, "admin:credits:read")
    items, next_cursor, has_more = await AdminBulkGrantService(
        session, request.app.state.settings
    ).deliveries(grant_id, limit=limit, cursor=cursor)
    return AdminBulkGrantDeliveryListResponse(
        items=[
            AdminBulkGrantDeliveryResponse.model_validate(item)
            for item in items
        ],
        pagination=Pagination(next_cursor=next_cursor, has_more=has_more),
    )



@router.get("/system/status", response_model=AdminSystemStatusResponse)
async def get_admin_system_status(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
) -> AdminSystemStatusResponse:
    _require_scope(principal, "admin:operations:read")
    status = await AdminSystemStatusService(
        request.app.state.settings,
        database=request.app.state.database,
        redis=request.app.state.redis,
        storage=request.app.state.minio,
    ).status(
        backend_version=request.app.version,
        started_at=request.app.state.started_at,
    )
    return AdminSystemStatusResponse.model_validate(status)


@router.get("/settings", response_model=AdminRuntimeSettingListResponse)
async def list_admin_runtime_settings(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRuntimeSettingListResponse:
    _require_owner(principal)
    items = await RuntimeSettingsService(
        session, request.app.state.settings
    ).list_settings()
    return AdminRuntimeSettingListResponse(
        items=[AdminRuntimeSettingResponse.model_validate(item) for item in items]
    )


@router.put(
    "/settings/{setting_key}",
    response_model=AdminRuntimeSettingResponse,
)
async def update_admin_runtime_setting(
    setting_key: str,
    payload: AdminRuntimeSettingUpdateRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRuntimeSettingResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = RuntimeSettingsService(session, request.app.state.settings)
    before, after = await service.update(
        setting_key,
        payload.value,
        actor_user_id=principal.user_id,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.runtime_setting.updated",
        resource_type="runtime_setting",
        resource_id=setting_key,
        context=_context(request),
        reason=payload.reason,
        before_state={"value": before},
        after_state={"value": after},
    )
    await session.commit()
    items = await service.list_settings()
    item = next(item for item in items if item["key"] == setting_key)
    return AdminRuntimeSettingResponse.model_validate(item)


@router.post(
    "/settings/{setting_key}/reset",
    response_model=AdminRuntimeSettingResponse,
)
async def reset_admin_runtime_setting(
    setting_key: str,
    payload: AdminRuntimeSettingResetRequest,
    request: Request,
    step_up_token: str | None = Header(default=None, alias="X-Admin-Step-Up"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRuntimeSettingResponse:
    _require_owner(principal)
    await _require_step_up(
        principal=principal,
        session=session,
        request=request,
        token=step_up_token,
    )
    service = RuntimeSettingsService(session, request.app.state.settings)
    before, after = await service.reset(setting_key)
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        actor_role=principal.role,
        action="admin.runtime_setting.reset",
        resource_type="runtime_setting",
        resource_id=setting_key,
        context=_context(request),
        reason=payload.reason,
        before_state={"value": before},
        after_state={"value": after, "source": "environment"},
    )
    await session.commit()
    items = await service.list_settings()
    item = next(item for item in items if item["key"] == setting_key)
    return AdminRuntimeSettingResponse.model_validate(item)
