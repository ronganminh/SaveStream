from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db_session
from app.application.billing.service import PaymentEventProcessor
from app.domain.common.errors import ApplicationError
from app.infrastructure.payments.factory import payment_provider_for_name

router = APIRouter(prefix="/v1/webhooks/payments", tags=["Billing"])


@router.post(
    "/{provider}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="paymentWebhook",
)
async def payment_webhook(
    provider: str,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    raw_body = await request.body()
    adapter = payment_provider_for_name(
        request.app.state.settings,
        provider,
    )
    event = adapter.verify_and_parse_webhook(
        raw_body,
        dict(request.headers),
    )
    try:
        raw_payload = json.loads(raw_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid payment webhook payload",
            status_code=400,
        ) from exc
    if not isinstance(raw_payload, dict):
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid payment webhook payload",
            status_code=400,
        )
    await PaymentEventProcessor(session, adapter).ingest(
        event,
        raw_payload=raw_payload,
        signature_verified=True,
    )
    response_status = (
        status.HTTP_200_OK
        if provider.strip().lower() == "lemonsqueezy"
        else status.HTTP_204_NO_CONTENT
    )
    return Response(status_code=response_status)
