from __future__ import annotations

import csv
import io
import uuid
from datetime import datetime

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
    AdminPaymentListResponse,
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
from app.application.admin.operations_d7 import AdminOperationsService
from app.application.admin.security import AdminSecurityService
from app.application.admin.service import AdminService
from app.application.audit.service import AuditContext, AuditService
from app.application.entitlements.service import EntitlementSnapshot
from app.application.identity.service import ip_hint
from app.application.privacy.service import PrivacyService
from app.application.billing.service import BillingAdminService
from app.application.credits.service import CreditAdminService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, has_scope, is_admin_role
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
    status_filter: str | None = Query(default=None, alias="status"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRecordingListResponse:
    _require_scope(principal, "admin:recordings:read")
    page = await AdminService(session, request.app.state.settings).list_recordings(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        status=status_filter,
    )
    return AdminRecordingListResponse(
        items=[recording_response(item) for item in page.items],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
    )


@router.get("/recordings/{recording_id}", response_model=RecordingResponse)
async def get_admin_recording(
    recording_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RecordingResponse:
    _require_scope(principal, "admin:recordings:read")
    recording = await AdminService(session, request.app.state.settings).get_recording(recording_id)
    return recording_response(recording)


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


@router.get("/payments", response_model=AdminPaymentListResponse)
async def list_admin_payments(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    user_id: uuid.UUID | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminPaymentListResponse:
    _require_scope(principal, "admin:payments:read")
    page = await AdminService(session, request.app.state.settings).list_payments(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        status=status_filter,
    )
    return AdminPaymentListResponse(
        items=[payment_order_response(item) for item in page.items],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
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
