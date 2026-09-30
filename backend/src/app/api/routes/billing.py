from __future__ import annotations

from fastapi import APIRouter, Depends, Header, Query, status

from app.api.dependencies import get_billing_service, require_scopes
from app.api.schemas.billing import (
    CheckoutRequest,
    CheckoutResponse,
    CreatePaymentOrderRequest,
    CreditPackageListResponse,
    PaymentOrderListResponse,
    PaymentOrderResponse,
)
from app.api.schemas.recordings import Pagination
from app.api.serializers.billing import package_response, payment_order_response
from app.application.billing.service import BillingService
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1/billing", tags=["Billing"])


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
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(require_scopes("billing:write")),
    service: BillingService = Depends(get_billing_service),
) -> PaymentOrderResponse:
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
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(require_scopes("billing:write")),
    service: BillingService = Depends(get_billing_service),
) -> CheckoutResponse:
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
