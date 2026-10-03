from __future__ import annotations

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, Header, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.admin import (
    AdminAdminListResponse,
    AdminCreditAdjustmentRequest,
    AdminCreditAdjustmentResponse,
    AdminMfaCodeRequest,
    AdminMfaResetRequest,
    AdminMfaSetupResponse,
    AdminMfaStatusResponse,
    AdminPaymentListResponse,
    AdminRecordingListResponse,
    AdminRefundRequest,
    AdminRefundResponse,
    AdminRetryRecordingResponse,
    AdminRoleUpdateRequest,
    AdminStepUpRequest,
    AdminStepUpResponse,
    AdminUserListResponse,
    AdminUserResponse,
    AdminUserUpdateRequest,
    AuditLogListResponse,
)
from app.api.schemas.recordings import Pagination, RecordingResponse
from app.api.serializers.admin import admin_user_response, audit_log_response
from app.api.serializers.billing import payment_order_response
from app.api.serializers.credits import transaction_response
from app.api.serializers.recordings import recording_response
from app.application.admin.security import AdminSecurityService
from app.application.admin.service import AdminService
from app.application.audit.service import AuditContext, AuditService
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
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserListResponse:
    _require_scope(principal, "admin:users:read")
    page = await AdminService(session, request.app.state.settings).list_users(
        limit=limit,
        cursor=cursor,
        role=role,
        is_active=is_active,
    )
    return AdminUserListResponse(
        items=[admin_user_response(item) for item in page.items],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
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
