from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_credit_service, require_scopes
from app.api.schemas.credits import (
    CreditBalanceResponse,
    CreditReservationListResponse,
    CreditTransactionListResponse,
)
from app.api.schemas.recordings import Pagination
from app.api.serializers.credits import reservation_response, transaction_response
from app.application.credits.service import CreditService
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1/credits", tags=["Credits"])


@router.get(
    "/balance",
    response_model=CreditBalanceResponse,
    operation_id="getCreditBalance",
)
async def get_credit_balance(
    principal: AuthPrincipal = Depends(require_scopes("credits:read")),
    service: CreditService = Depends(get_credit_service),
) -> CreditBalanceResponse:
    balance = await service.balance(principal.user_id)
    return CreditBalanceResponse(
        posted=balance.posted,
        reserved=balance.reserved,
        available=balance.available,
    )


@router.get(
    "/transactions",
    response_model=CreditTransactionListResponse,
    operation_id="listCreditTransactions",
)
async def list_credit_transactions(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(require_scopes("credits:read")),
    service: CreditService = Depends(get_credit_service),
) -> CreditTransactionListResponse:
    page = await service.transactions(
        principal.user_id,
        limit=limit,
        cursor=cursor,
    )
    return CreditTransactionListResponse(
        items=[transaction_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.get(
    "/reservations",
    response_model=CreditReservationListResponse,
    operation_id="listCreditReservations",
)
async def list_credit_reservations(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(require_scopes("credits:read")),
    service: CreditService = Depends(get_credit_service),
) -> CreditReservationListResponse:
    page = await service.reservations(
        principal.user_id,
        limit=limit,
        cursor=cursor,
    )
    return CreditReservationListResponse(
        items=[reservation_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )
