from __future__ import annotations

import asyncio
import base64
import json
from datetime import datetime, timezone
from typing import Any, Callable, Mapping

import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import id_token, service_account

from app.domain.common.errors import ApplicationError
from app.settings import AppSettings

from .base import StoreReceiptVerifier, VerifiedStorePurchase, VerifiedStoreRefund

_ANDROID_PUBLISHER_SCOPE = "https://www.googleapis.com/auth/androidpublisher"


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
        verified_product_id = str(payload.get("productId") or "")
        if (
            int(payload.get("purchaseState", -1)) != 0
            or verified_product_id != product_id
            or order_id != transaction_id
            or int(payload.get("quantity", 1)) != 1
        ):
            raise _invalid(
                "Google Play purchase does not match the requested purchase"
            )

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

    async def verify_refund_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> VerifiedStoreRefund:
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
            voided = data["voidedPurchaseNotification"]
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            TypeError,
            ValueError,
        ) as exc:
            raise _invalid("Google Play RTDN payload is invalid") from exc

        if (
            str(data.get("packageName") or "")
            != self.settings.google_play_package_name
            or int(voided.get("productType", 0)) != 2
        ):
            raise _invalid("Google Play RTDN does not match this app")
        order_id = str(voided.get("orderId") or "")
        if not order_id or not message_id:
            raise _invalid("Google Play refund notification is incomplete")
        return VerifiedStoreRefund(
            platform=self.platform,
            transaction_id=order_id,
            event_id=message_id,
        )
