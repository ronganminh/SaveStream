from __future__ import annotations

import json

from fastapi import APIRouter, Depends, Request, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db_session
from app.application.billing.store import StorePurchaseService
from app.domain.common.errors import ApplicationError
from app.infrastructure.store.apple import AppleStoreReceiptVerifier
from app.infrastructure.store.base import StoreReceiptVerifier, VerifiedStoreRefund
from app.infrastructure.store.factory import store_receipt_verifier_for_platform
from app.infrastructure.store.google_play import GooglePlayReceiptVerifier

router = APIRouter(prefix="/v1/webhooks", tags=["Billing"])


async def _apply_store_refund(
    raw_body: bytes,
    verifier: StoreReceiptVerifier,
    refund: VerifiedStoreRefund,
    session: AsyncSession,
) -> Response:
    try:
        raw_payload = json.loads(raw_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "STORE_RECEIPT_INVALID",
            "Store notification is invalid",
            status_code=422,
        ) from exc
    if not isinstance(raw_payload, dict):
        raise ApplicationError(
            "STORE_RECEIPT_INVALID",
            "Store notification is invalid",
            status_code=422,
        )
    await StorePurchaseService(session, verifier).apply_refund(
        refund,
        raw_payload=raw_payload,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)


async def _store_refund_webhook(
    platform: str,
    request: Request,
    session: AsyncSession,
) -> Response:
    raw_body = await request.body()
    verifier = store_receipt_verifier_for_platform(
        request.app.state.settings,
        platform,
    )
    refund = await verifier.verify_refund_notification(
        raw_body,
        dict(request.headers),
    )
    return await _apply_store_refund(raw_body, verifier, refund, session)


@router.post(
    "/app-store",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="appStoreWebhook",
)
async def app_store_webhook(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    verifier = store_receipt_verifier_for_platform(
        request.app.state.settings, "app_store"
    )
    if not isinstance(verifier, AppleStoreReceiptVerifier):
        # A disabled provider still fails closed; fake test verifiers retain
        # the legacy refund-only interface.
        return await _store_refund_webhook("app_store", request, session)

    raw_body = await request.body()
    refund = await verifier.verify_notification(raw_body)
    if refund is None:
        # TEST and other valid signed notifications do not mutate balances.
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    return await _apply_store_refund(raw_body, verifier, refund, session)


@router.post(
    "/google-play",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="googlePlayWebhook",
)
async def google_play_webhook(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> Response:
    verifier = store_receipt_verifier_for_platform(
        request.app.state.settings, "google_play"
    )
    if not isinstance(verifier, GooglePlayReceiptVerifier):
        # Disabled providers fail closed; fake test verifiers are refund-only.
        return await _store_refund_webhook("google_play", request, session)

    raw_body = await request.body()
    notification = await verifier.parse_notification(raw_body, dict(request.headers))
    if notification.kind == "refund" and notification.refund is not None:
        return await _apply_store_refund(raw_body, verifier, notification.refund, session)
    if (
        notification.kind == "purchased"
        and notification.product_id
        and notification.store_token
    ):
        try:
            raw_payload = json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raw_payload = {}
        try:
            await StorePurchaseService(session, verifier).handle_purchased_notification(
                product_id=notification.product_id,
                store_token=notification.store_token,
                raw_payload=raw_payload if isinstance(raw_payload, dict) else {},
            )
        except ApplicationError as exc:
            if exc.retryable:
                # Let Pub/Sub retry when Google Play itself was unavailable.
                raise
    # Test, subscription and cancelled-purchase notifications need no action.
    return Response(status_code=status.HTTP_204_NO_CONTENT)
