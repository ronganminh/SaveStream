from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, Header, Query, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.admin import (
    AdminCreditAdjustmentRequest,
    AdminCreditAdjustmentResponse,
    AdminPaymentListResponse,
    AdminRecordingListResponse,
    AdminRefundRequest,
    AdminRefundResponse,
    AdminRetryRecordingResponse,
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
from app.application.admin.service import AdminService
from app.application.audit.service import AuditContext, AuditService
from app.application.billing.service import BillingAdminService
from app.application.credits.service import CreditAdminService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.payments.factory import selected_payment_provider

router = APIRouter(
    prefix="/v1/admin",
    tags=["Admin"],
    include_in_schema=False,
)


def _require_admin(principal: AuthPrincipal) -> None:
    if principal.role != "admin" and "admin:*" not in principal.scopes:
        raise ApplicationError(
            "FORBIDDEN",
            "Admin permission is required",
            status_code=403,
        )


def _context(request: Request) -> AuditContext:
    client_ip = request.client.host if request.client else None
    return AuditContext(
        request_id=getattr(request.state, "request_id", None),
        ip_address=client_ip,
        user_agent=request.headers.get("user-agent"),
    )


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
    _require_admin(principal)
    page = await AdminService(
        session, request.app.state.settings
    ).list_users(
        limit=limit,
        cursor=cursor,
        role=role,
        is_active=is_active,
    )
    return AdminUserListResponse(
        items=[admin_user_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.get("/users/{user_id}", response_model=AdminUserResponse)
async def get_admin_user(
    user_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_admin(principal)
    return admin_user_response(
        await AdminService(
            session, request.app.state.settings
        ).get_user(user_id)
    )


@router.patch("/users/{user_id}", response_model=AdminUserResponse)
async def update_admin_user(
    user_id: str,
    payload: AdminUserUpdateRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminUserResponse:
    _require_admin(principal)
    service = AdminService(session, request.app.state.settings)
    user = await service.update_user(
        actor_user_id=principal.user_id,
        user_id=user_id,
        role=payload.role,
        is_active=payload.is_active,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        action="admin.user.updated",
        resource_type="user",
        resource_id=str(user.id),
        context=_context(request),
        details=payload.model_dump(exclude_none=True),
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
    _require_admin(principal)
    page = await AdminService(
        session, request.app.state.settings
    ).list_recordings(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        status=status_filter,
    )
    return AdminRecordingListResponse(
        items=[recording_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.get("/recordings/{recording_id}", response_model=RecordingResponse)
async def get_admin_recording(
    recording_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RecordingResponse:
    _require_admin(principal)
    recording = await AdminService(
        session, request.app.state.settings
    ).get_recording(recording_id)
    return recording_response(recording)


@router.post(
    "/recordings/{recording_id}/retry",
    response_model=AdminRetryRecordingResponse,
)
async def retry_admin_recording(
    recording_id: str,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRetryRecordingResponse:
    _require_admin(principal)
    original, retry = await AdminService(
        session, request.app.state.settings
    ).retry_recording(
        recording_id=recording_id,
        idempotency_key=idempotency_key,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        action="admin.recording.retried",
        resource_type="recording",
        resource_id=str(original.id),
        context=_context(request),
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
    _require_admin(principal)
    page = await AdminService(
        session, request.app.state.settings
    ).list_payments(
        limit=limit,
        cursor=cursor,
        user_id=user_id,
        status=status_filter,
    )
    return AdminPaymentListResponse(
        items=[payment_order_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.post(
    "/payments/{payment_order_id}/refunds",
    response_model=AdminRefundResponse,
)
async def refund_admin_payment(
    payment_order_id: str,
    payload: AdminRefundRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminRefundResponse:
    _require_admin(principal)
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
        action="admin.payment.refund_requested",
        resource_type="payment_order",
        resource_id=payment_order_id,
        context=_context(request),
        details={
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


@router.post(
    "/credits/adjustments",
    response_model=AdminCreditAdjustmentResponse,
)
async def adjust_admin_credit(
    payload: AdminCreditAdjustmentRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AdminCreditAdjustmentResponse:
    _require_admin(principal)
    try:
        user_id = uuid.UUID(payload.user_id)
    except ValueError as exc:
        raise ApplicationError(
            "RESOURCE_NOT_FOUND", "User not found", status_code=404
        ) from exc
    transaction = await CreditAdminService(session).adjust(
        user_id=user_id,
        amount=payload.amount,
        idempotency_key=idempotency_key,
        reason=payload.reason,
        commit=False,
    )
    await AuditService(session).record(
        actor_user_id=principal.user_id,
        action="admin.credit.adjusted",
        resource_type="user",
        resource_id=str(user_id),
        context=_context(request),
        details={
            "transaction_id": str(transaction.id),
            "amount": payload.amount,
            "reason": payload.reason,
        },
    )
    await session.commit()
    return AdminCreditAdjustmentResponse(
        transaction=transaction_response(transaction)
    )


@router.get("/audit", response_model=AuditLogListResponse)
async def list_admin_audit(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    actor_user_id: uuid.UUID | None = Query(default=None),
    resource_type: str | None = Query(default=None),
    action: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> AuditLogListResponse:
    _require_admin(principal)
    page = await AuditService(session).list(
        limit=limit,
        cursor=cursor,
        actor_user_id=actor_user_id,
        resource_type=resource_type,
        action=action,
    )
    return AuditLogListResponse(
        items=[audit_log_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )
