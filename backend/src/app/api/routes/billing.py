from __future__ import annotations

from fastapi import APIRouter, Depends, Header, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import (
    get_billing_service,
    get_db_session,
    require_scopes,
)
from app.api.schemas.billing import (
    CheckoutRequest,
    CheckoutResponse,
    CreatePaymentOrderRequest,
    CreditPackageListResponse,
    PaymentOrderListResponse,
    PaymentOrderResponse,
    StorePurchaseRequest,
    StorePurchaseResponse,
)
from app.api.schemas.recordings import Pagination
from app.api.serializers.billing import package_response, payment_order_response
from app.application.billing.service import BillingService
from app.application.billing.store import StorePurchaseService
from app.application.runtime_settings import RuntimeSettingsService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.store.factory import store_receipt_verifier_for_platform

router = APIRouter(prefix="/v1/billing", tags=["Billing"])


async def _require_payment_channel(
    session: AsyncSession,
    request: Request,
    *,
    setting_key: str,
    channel: str,
) -> None:
    enabled = await RuntimeSettingsService(
        session, request.app.state.settings
    ).boolean(setting_key)
    if not enabled:
        raise ApplicationError(
            "SERVICE_UNAVAILABLE",
            f"{channel} payments are disabled",
            status_code=503,
            retryable=False,
            details={"channel": channel},
        )


@router.get(
    "/packages",
    response_model=CreditPackageListResponse,
    operation_id="listCreditPackages",
)
async def list_packages(
    principal: AuthPrincipal = Depends(require_scopes("billing:read")),
    service: BillingService = Depends(get_billing_service),
) -> CreditPackageListResponse:
    del principal
    return CreditPackageListResponse(
        items=[package_response(item) for item in await service.packages()]
    )


@router.post(
    "/payment-orders",
    response_model=PaymentOrderResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createPaymentOrder",
)
async def create_payment_order(
    payload: CreatePaymentOrderRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(require_scopes("billing:write")),
    service: BillingService = Depends(get_billing_service),
    session: AsyncSession = Depends(get_db_session),
) -> PaymentOrderResponse:
    await _require_payment_channel(
        session,
        request,
        setting_key="payment_web_enabled",
        channel="web",
    )
    order = await service.create_order(
        user_id=principal.user_id,
        package_id=payload.package_id,
        idempotency_key=idempotency_key,
    )
    return payment_order_response(order)


@router.get(
    "/payment-orders",
    response_model=PaymentOrderListResponse,
    operation_id="listPaymentOrders",
)
async def list_payment_orders(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(require_scopes("billing:read")),
    service: BillingService = Depends(get_billing_service),
) -> PaymentOrderListResponse:
    page = await service.list(
        user_id=principal.user_id,
        limit=limit,
        cursor=cursor,
    )
    return PaymentOrderListResponse(
        items=[payment_order_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.get(
    "/payment-orders/{payment_order_id}",
    response_model=PaymentOrderResponse,
    operation_id="getPaymentOrder",
)
async def get_payment_order(
    payment_order_id: str,
    principal: AuthPrincipal = Depends(require_scopes("billing:read")),
    service: BillingService = Depends(get_billing_service),
) -> PaymentOrderResponse:
    return payment_order_response(
        await service.get(
            user_id=principal.user_id,
            payment_order_id=payment_order_id,
        )
    )


@router.post(
    "/payment-orders/{payment_order_id}/checkout",
    response_model=CheckoutResponse,
    operation_id="createPaymentCheckout",
)
async def create_payment_checkout(
    payment_order_id: str,
    payload: CheckoutRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(require_scopes("billing:write")),
    service: BillingService = Depends(get_billing_service),
    session: AsyncSession = Depends(get_db_session),
) -> CheckoutResponse:
    await _require_payment_channel(
        session,
        request,
        setting_key="payment_web_enabled",
        channel="web",
    )
    result = await service.checkout(
        user_id=principal.user_id,
        payment_order_id=payment_order_id,
        return_url=payload.return_url,
        idempotency_key=idempotency_key,
    )
    return CheckoutResponse(
        checkout_url=result.checkout_url,
        payment_order=payment_order_response(result.payment_order),
    )


@router.post(
    "/store-purchases",
    response_model=StorePurchaseResponse,
    operation_id="createStorePurchase",
)
async def create_store_purchase(
    payload: StorePurchaseRequest,
    request: Request,
    principal: AuthPrincipal = Depends(require_scopes("billing:write")),
    session: AsyncSession = Depends(get_db_session),
) -> StorePurchaseResponse:
    setting_key = (
        "payment_app_store_enabled"
        if payload.platform == "app_store"
        else "payment_google_play_enabled"
    )
    await _require_payment_channel(
        session,
        request,
        setting_key=setting_key,
        channel=payload.platform,
    )
    verifier = store_receipt_verifier_for_platform(
        request.app.state.settings,
        payload.platform,
    )
    result = await StorePurchaseService(session, verifier).purchase(
        user_id=principal.user_id,
        product_id=payload.product_id,
        transaction_id=payload.transaction_id,
        receipt=payload.receipt,
    )
    return StorePurchaseResponse(
        status=result.status,
        payment_order_id=str(result.payment_order_id),
        cloud_minutes_added=result.cloud_minutes_added,
        cloud_minutes_available=result.cloud_minutes_available,
    )
