from __future__ import annotations

import asyncio
import base64
import hashlib
import json
import logging
from datetime import datetime, timezone
from typing import Any, Callable, Mapping

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token, service_account

from app.domain.common.errors import ApplicationError
from app.settings import AppSettings

from .base import (
    StoreNotification,
    StoreReceiptVerifier,
    VerifiedStorePurchase,
    VerifiedStoreRefund,
)

logger = logging.getLogger(__name__)

_ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"
# purchases.products purchaseState
_PURCHASED = 0
_PENDING = 2
# oneTimeProductNotification.notificationType
_ONE_TIME_PRODUCT_PURCHASED = 1


def voided_event_id(store_token: str) -> str:
    """Stable id for a voided purchase found by reconciliation (not by RTDN)."""
    return "voided:" + hashlib.sha256(store_token.encode("utf-8")).hexdigest()[:40]


def _invalid(message: str) -> ApplicationError:
    return ApplicationError(
        "STORE_RECEIPT_INVALID",
        message,
        status_code=422,
        retryable=False,
    )


class GooglePlayReceiptVerifier(StoreReceiptVerifier):
    platform = "google_play"

    def __init__(
        self,
        settings: AppSettings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
        credentials: Any | None = None,
        oidc_verifier: Callable[[str], Mapping[str, object]] | None = None,
    ) -> None:
        self.settings = settings
        self.transport = transport
        if credentials is None:
            try:
                info = json.loads(settings.google_play_service_account_json)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    "Invalid Google Play service account JSON"
                ) from exc
            credentials = service_account.Credentials.from_service_account_info(
                info,
                scopes=[_ANDROID_PUBLISHER_SCOPE],
            )
        self.credentials = credentials
        self.oidc_verifier = oidc_verifier or self._verify_oidc

    async def _access_token(self) -> str:
        if not self.credentials.valid or not self.credentials.token:
            await asyncio.to_thread(
                self.credentials.refresh,
                GoogleAuthRequest(),
            )
        token = self.credentials.token
        if not token:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Google Play authorization failed",
                status_code=503,
                retryable=True,
            )
        return str(token)

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, object] | None = None,
    ) -> httpx.Response:
        token = await self._access_token()
        async with httpx.AsyncClient(
            base_url="https://androidpublisher.googleapis.com",
            transport=self.transport,
            timeout=self.settings.store_purchase_timeout_seconds,
        ) as client:
            return await client.request(
                method,
                path,
                headers={"Authorization": f"Bearer {token}"},
                json=json_body,
            )

    async def verify_purchase(
        self,
        *,
        product_id: str,
        transaction_id: str,
        receipt: str,
    ) -> VerifiedStorePurchase:
        path = (
            f"/androidpublisher/v3/applications/"
            f"{self.settings.google_play_package_name}/purchases/products/"
            f"{product_id}/tokens/{receipt}"
        )
        response = await self._request("GET", path)
        if response.status_code >= 400:
            # 401/403: the service account can't read purchases (not invited
            # in Play Console, or lacks the financial-data permission).
            logger.warning(
                "Google Play purchase lookup failed product=%s status=%s: %s",
                product_id,
                response.status_code,
                response.text[:300].replace(receipt, "<token>"),
            )
        # Google returns 400 for malformed/unknown purchase tokens and may
        # return 404 or 410 for tokens that no longer resolve.  All three are
        # terminal receipt failures; treating 400 as a transient 503 makes the
        # mobile retry queue loop forever on a receipt Google will never accept.
        if response.status_code in {400, 404, 410}:
            raise _invalid("Google Play purchase token is invalid")
        if response.status_code >= 400:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Google Play verification is temporarily unavailable",
                status_code=503,
                retryable=True,
            )
        try:
            payload = response.json()
        except json.JSONDecodeError as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Google Play verification response is invalid",
                status_code=503,
                retryable=True,
            ) from exc

        order_id = str(payload.get("orderId") or "")
        # ProductPurchase.productId and quantity are documented as "may not
        # be present" (production purchases usually omit productId). The
        # token was looked up under product_id in the URL, so only a
        # productId that is present and different is a mismatch.
        verified_product_id = str(payload.get("productId") or "")
        state = int(payload.get("purchaseState", -1))
        if state not in {_PURCHASED, _PENDING}:
            # 1 = cancelled: refunded, or not acknowledged in time (Google
            # refunds test purchases after a few minutes).
            raise _invalid(
                f"Google Play purchase is not active (purchaseState={state})"
            )
        if verified_product_id and verified_product_id != product_id:
            raise _invalid("Google Play purchase is for another product")
        # orderId is empty for promo codes, so the app may send the purchase
        # token as its transaction id instead.
        if order_id and transaction_id not in {order_id, receipt}:
            raise _invalid("Google Play purchase order does not match")
        if int(payload.get("quantity") or 1) != 1:
            raise _invalid("Google Play purchase quantity is not 1")

        purchased_at = None
        purchase_millis = payload.get("purchaseTimeMillis")
        if purchase_millis is not None:
            try:
                purchased_at = datetime.fromtimestamp(
                    int(str(purchase_millis)) / 1000,
                    tz=timezone.utc,
                )
            except ValueError as exc:
                raise ApplicationError(
                    "SERVICE_UNAVAILABLE",
                    "Google Play purchase time is invalid",
                    status_code=503,
                    retryable=True,
                ) from exc

        return VerifiedStorePurchase(
            platform=self.platform,
            product_id=product_id,
            transaction_id=transaction_id,
            purchased_at=purchased_at,
            store_token=receipt,
            needs_acknowledge=int(
                payload.get("acknowledgementState", 0)
            ) == 0,
            needs_consume=int(payload.get("consumptionState", 0)) == 0,
            pending=state == _PENDING,
            account_reference=(
                str(payload.get("obfuscatedExternalAccountId") or "") or None
            ),
            store_order_id=order_id or None,
        )

    async def finalize_purchase(
        self,
        purchase: VerifiedStorePurchase,
    ) -> None:
        if not purchase.store_token:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Google Play purchase token is missing",
                status_code=503,
                retryable=True,
            )
        prefix = (
            f"/androidpublisher/v3/applications/"
            f"{self.settings.google_play_package_name}/purchases/products/"
            f"{purchase.product_id}/tokens/{purchase.store_token}"
        )
        if purchase.needs_acknowledge:
            response = await self._request(
                "POST",
                f"{prefix}:acknowledge",
                json_body={},
            )
            if response.status_code >= 400:
                raise ApplicationError(
                    "SERVICE_UNAVAILABLE",
                    "Google Play acknowledge failed",
                    status_code=503,
                    retryable=True,
                )
        if purchase.needs_consume:
            response = await self._request(
                "POST",
                f"{prefix}:consume",
                json_body={},
            )
            if response.status_code >= 400:
                raise ApplicationError(
                    "SERVICE_UNAVAILABLE",
                    "Google Play consume failed",
                    status_code=503,
                    retryable=True,
                )

    def _verify_oidc(self, token: str) -> Mapping[str, object]:
        try:
            claims = id_token.verify_oauth2_token(
                token,
                GoogleAuthRequest(),
                audience=self.settings.google_play_rtdn_audience,
            )
        except Exception as exc:
            raise _invalid("Google Play RTDN identity token is invalid") from exc
        if (
            claims.get("email")
            != self.settings.google_play_rtdn_service_account_email
            or claims.get("email_verified") is not True
        ):
            raise _invalid("Google Play RTDN sender is not authorized")
        return claims

    async def parse_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> StoreNotification:
        """Verify a Real-time developer notification (Pub/Sub push).

        Test, subscription and cancelled-purchase notifications are valid but
        need no action, so they come back as ``ignored`` and are acknowledged
        with 204; answering them with an error makes Pub/Sub retry for days.
        """
        authorization = (
            headers.get("authorization")
            or headers.get("Authorization")
            or ""
        )
        if not authorization.startswith("Bearer "):
            raise _invalid("Google Play RTDN authorization is missing")
        await asyncio.to_thread(
            self.oidc_verifier,
            authorization[7:].strip(),
        )

        try:
            envelope = json.loads(raw_body.decode("utf-8"))
            message = envelope["message"]
            encoded_data = str(message["data"])
            message_id = str(message["messageId"])
            data = json.loads(
                base64.b64decode(encoded_data, validate=True).decode("utf-8")
            )
            if not isinstance(data, dict):
                raise TypeError("RTDN data is not an object")
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            TypeError,
            ValueError,
        ) as exc:
            raise _invalid("Google Play RTDN payload is invalid") from exc

        if str(data.get("packageName") or "") != self.settings.google_play_package_name:
            raise _invalid("Google Play RTDN does not match this app")

        voided = data.get("voidedPurchaseNotification")
        if isinstance(voided, dict):
            if int(voided.get("productType", 0)) != 2:
                # Subscriptions are not sold.
                return StoreNotification(kind="ignored")
            order_id = str(voided.get("orderId") or "")
            token = str(voided.get("purchaseToken") or "")
            if not (order_id or token) or not message_id:
                raise _invalid("Google Play refund notification is incomplete")
            return StoreNotification(
                kind="refund",
                refund=VerifiedStoreRefund(
                    platform=self.platform,
                    transaction_id=order_id or token,
                    event_id=message_id,
                    store_token=token or None,
                ),
            )

        one_time = data.get("oneTimeProductNotification")
        if isinstance(one_time, dict):
            token = str(one_time.get("purchaseToken") or "")
            sku = str(one_time.get("sku") or "")
            if (
                int(one_time.get("notificationType", 0)) == _ONE_TIME_PRODUCT_PURCHASED
                and token
                and sku
            ):
                return StoreNotification(
                    kind="purchased", product_id=sku, store_token=token
                )
        # testNotification, subscriptionNotification, cancelled purchases.
        return StoreNotification(kind="ignored")

    async def verify_refund_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> VerifiedStoreRefund:
        notification = await self.parse_notification(raw_body, headers)
        if notification.refund is None:
            raise _invalid("Google Play RTDN is not a refund")
        return notification.refund

    async def list_voided(self, since: datetime) -> list[VerifiedStoreRefund]:
        """Refunds and chargebacks since ``since`` (Voided Purchases API).

        Daily reconciliation in case a refund notification was lost.
        """
        refunds: list[VerifiedStoreRefund] = []
        page_token = ""
        start = int(since.timestamp() * 1000)
        base = (
            f"/androidpublisher/v3/applications/"
            f"{self.settings.google_play_package_name}/purchases/voidedpurchases"
            f"?type=0&startTime={start}&maxResults=1000"
        )
        for _ in range(20):
            response = await self._request(
                "GET", base + (f"&token={page_token}" if page_token else "")
            )
            if response.status_code >= 400:
                raise ApplicationError(
                    "SERVICE_UNAVAILABLE",
                    "Google Play voided purchases are temporarily unavailable",
                    status_code=503,
                    retryable=True,
                )
            payload = response.json()
            for item in payload.get("voidedPurchases") or []:
                token = str(item.get("purchaseToken") or "")
                if not token:
                    continue
                refunds.append(
                    VerifiedStoreRefund(
                        platform=self.platform,
                        transaction_id=str(item.get("orderId") or "") or token,
                        event_id=voided_event_id(token),
                        store_token=token,
                    )
                )
            page_token = str(
                (payload.get("tokenPagination") or {}).get("nextPageToken") or ""
            )
            if not page_token:
                break
        return refunds
