from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Mapping
from urllib.parse import quote

import httpx

from app.domain.common.errors import ApplicationError
from app.settings import AppSettings

from .base import (
    CheckoutSession,
    ProviderEvent,
    ProviderPaymentState,
    ProviderRefundState,
    RefundSession,
)


class PayPalPaymentProvider:
    """PayPal Orders v2 adapter for one-time SaveStream credit purchases.

    The browser only receives the public PayPal order id. Client secret usage,
    capture, reconciliation, and refunds stay on the backend.
    """

    name = "paypal"

    def __init__(
        self,
        settings: AppSettings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.settings = settings
        self.base_url = (
            settings.payment_provider_base_url or "https://api-m.paypal.com"
        ).rstrip("/")
        self._transport = transport

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            timeout=self.settings.payment_timeout_seconds,
            transport=self._transport,
        )

    async def _access_token(self) -> str:
        try:
            async with self._client() as client:
                response = await client.post(
                    f"{self.base_url}/v1/oauth2/token",
                    auth=httpx.BasicAuth(
                        self.settings.paypal_client_id,
                        self.settings.paypal_client_secret,
                    ),
                    headers={
                        "Accept": "application/json",
                        "Accept-Language": "en_US",
                    },
                    data={"grant_type": "client_credentials"},
                )
                response.raise_for_status()
                token = str(response.json()["access_token"]).strip()
                if not token:
                    raise ValueError("empty PayPal access token")
                return token
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "PayPal authentication failed",
                status_code=503,
                retryable=True,
            ) from exc

    async def _headers(self, *, request_id: str | None = None) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {await self._access_token()}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }
        if request_id:
            headers["PayPal-Request-Id"] = request_id[:108]
        return headers

    @staticmethod
    def _usd_value(amount_minor: int, currency: str) -> str:
        if currency.upper() != "USD":
            raise ApplicationError(
                "PAYMENT_FAILED",
                "PayPal web checkout currently supports USD packages only",
                status_code=409,
            )
        if amount_minor < 0:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Invalid PayPal order amount",
                status_code=409,
            )
        return f"{amount_minor / 100:.2f}"

    @staticmethod
    def _approval_url(payload: object) -> str:
        if not isinstance(payload, dict):
            raise ValueError("invalid PayPal order response")
        links = payload.get("links", [])
        if not isinstance(links, list):
            raise ValueError("invalid PayPal order links")
        for link in links:
            if isinstance(link, dict) and link.get("rel") in {"approve", "payer-action"}:
                href = str(link.get("href", "")).strip()
                if href.startswith("https://"):
                    return href
        raise ValueError("PayPal approval URL missing")

    @staticmethod
    def _capture_from_order(payload: object) -> dict[str, object] | None:
        if not isinstance(payload, dict):
            return None
        purchase_units = payload.get("purchase_units")
        if not isinstance(purchase_units, list):
            return None
        for unit in purchase_units:
            if not isinstance(unit, dict):
                continue
            payments = unit.get("payments")
            if not isinstance(payments, dict):
                continue
            captures = payments.get("captures")
            if not isinstance(captures, list):
                continue
            for capture in captures:
                if isinstance(capture, dict):
                    return capture
        return None

    @staticmethod
    def _payment_state(payload: object, provider_reference: str) -> ProviderPaymentState:
        if not isinstance(payload, dict):
            raise ValueError("invalid PayPal payment response")
        order_status = str(payload.get("status", "")).upper()
        capture = PayPalPaymentProvider._capture_from_order(payload)
        amount: object | None = None
        event_id = provider_reference
        if capture is not None:
            amount = capture.get("amount")
            event_id = str(capture.get("id") or provider_reference)
            capture_status = str(capture.get("status", "")).upper()
            if capture_status == "COMPLETED":
                normalized = "paid"
            elif capture_status in {"DECLINED", "FAILED"}:
                normalized = "failed"
            else:
                normalized = "pending"
        else:
            purchase_units = payload.get("purchase_units")
            if isinstance(purchase_units, list) and purchase_units:
                first = purchase_units[0]
                if isinstance(first, dict):
                    amount = first.get("amount")
            normalized = {
                "COMPLETED": "paid",
                "VOIDED": "cancelled",
            }.get(order_status, "pending")
        if not isinstance(amount, dict):
            raise ValueError("PayPal amount missing")
        currency = str(amount["currency_code"]).upper()
        value = str(amount["value"])
        if currency != "USD":
            raise ValueError("unsupported PayPal currency")
        try:
            amount_minor = int((Decimal(value) * 100).to_integral_exact())
        except (InvalidOperation, ValueError) as exc:
            raise ValueError("invalid PayPal amount") from exc
        return ProviderPaymentState(
            event_id=event_id,
            status=normalized,
            provider_reference=provider_reference,
            amount_minor=amount_minor,
            currency=currency,
        )

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
        variant_id: str | None = None,
    ) -> CheckoutSession:
        del variant_id
        payload = {
            "intent": "CAPTURE",
            "purchase_units": [
                {
                    "reference_id": order_id,
                    "custom_id": order_id,
                    "description": "SaveStream cloud recording credits",
                    "amount": {
                        "currency_code": currency.upper(),
                        "value": self._usd_value(amount_minor, currency),
                    },
                }
            ],
            "payment_source": {
                "paypal": {
                    "experience_context": {
                        "user_action": "PAY_NOW",
                        "return_url": return_url,
                        "cancel_url": return_url,
                    }
                }
            },
        }
        try:
            async with self._client() as client:
                response = await client.post(
                    f"{self.base_url}/v2/checkout/orders",
                    headers=await self._headers(
                        request_id=f"savestream-create-{order_id}"
                    ),
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
            provider_reference = str(data["id"])
            return CheckoutSession(
                provider_reference=provider_reference,
                checkout_url=self._approval_url(data),
            )
        except ApplicationError:
            raise
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "PayPal order creation failed",
                status_code=502,
                retryable=True,
            ) from exc

    async def capture_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState:
        try:
            async with self._client() as client:
                response = await client.post(
                    f"{self.base_url}/v2/checkout/orders/{quote(provider_reference, safe='')}/capture",
                    headers=await self._headers(
                        request_id=f"savestream-capture-{provider_reference}"
                    ),
                    json={},
                )
                if response.status_code in {409, 422}:
                    return await self.retrieve_payment(provider_reference) or self._raise_capture_failed()
                response.raise_for_status()
                state = self._payment_state(response.json(), provider_reference)
            if state.status != "paid":
                raise ApplicationError(
                    "PAYMENT_FAILED",
                    "PayPal did not complete the capture",
                    status_code=409,
                    retryable=True,
                )
            return state
        except ApplicationError:
            raise
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "PayPal capture failed",
                status_code=502,
                retryable=True,
            ) from exc

    @staticmethod
    def _raise_capture_failed() -> ProviderPaymentState:
        raise ApplicationError(
            "PAYMENT_FAILED",
            "PayPal capture could not be confirmed",
            status_code=409,
            retryable=True,
        )

    async def retrieve_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState | None:
        try:
            async with self._client() as client:
                response = await client.get(
                    f"{self.base_url}/v2/checkout/orders/{quote(provider_reference, safe='')}",
                    headers=await self._headers(),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                return self._payment_state(response.json(), provider_reference)
        except ApplicationError:
            raise
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "PayPal reconciliation failed",
                status_code=503,
                retryable=True,
            ) from exc

    async def create_refund(
        self,
        *,
        refund_id: str,
        provider_reference: str,
        amount_minor: int,
        currency: str,
    ) -> RefundSession:
        payment = await self._get_order_payload(provider_reference)
        capture = self._capture_from_order(payment)
        if capture is None or not capture.get("id"):
            raise ApplicationError(
                "PAYMENT_FAILED",
                "PayPal capture is not available for refund",
                status_code=409,
            )
        capture_id = str(capture["id"])
        payload = {
            "amount": {
                "currency_code": currency.upper(),
                "value": self._usd_value(amount_minor, currency),
            },
        }
        try:
            async with self._client() as client:
                response = await client.post(
                    f"{self.base_url}/v2/payments/captures/{quote(capture_id, safe='')}/refund",
                    headers=await self._headers(
                        request_id=f"savestream-refund-{refund_id}"
                    ),
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
            paypal_refund_id = str(data["id"])
            return RefundSession(
                provider_refund_reference=(
                    f"paypal:{provider_reference}:{paypal_refund_id}"
                )
            )
        except ApplicationError:
            raise
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "PayPal refund failed",
                status_code=502,
                retryable=True,
            ) from exc

    async def _get_order_payload(self, provider_reference: str) -> object:
        try:
            async with self._client() as client:
                response = await client.get(
                    f"{self.base_url}/v2/checkout/orders/{quote(provider_reference, safe='')}",
                    headers=await self._headers(),
                )
                response.raise_for_status()
                return response.json()
        except (httpx.HTTPError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "PayPal order lookup failed",
                status_code=503,
                retryable=True,
            ) from exc

    async def retrieve_refund(
        self,
        provider_refund_reference: str,
    ) -> ProviderRefundState | None:
        parts = provider_refund_reference.split(":", 2)
        if len(parts) != 3 or parts[0] != "paypal":
            return None
        _, order_id, refund_id = parts
        try:
            async with self._client() as client:
                response = await client.get(
                    f"{self.base_url}/v2/payments/refunds/{quote(refund_id, safe='')}",
                    headers=await self._headers(),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                data = response.json()
            amount = data["amount"]
            if not isinstance(amount, dict):
                raise ValueError("PayPal refund amount missing")
            currency = str(amount["currency_code"]).upper()
            if currency != "USD":
                raise ValueError("unsupported PayPal refund currency")
            try:
                amount_minor = int(
                    (Decimal(str(amount["value"])) * 100).to_integral_exact()
                )
            except (InvalidOperation, ValueError) as exc:
                raise ValueError("invalid PayPal refund amount") from exc
            status = {
                "COMPLETED": "succeeded",
                "FAILED": "failed",
                "CANCELLED": "failed",
            }.get(str(data.get("status", "")).upper(), "pending")
            return ProviderRefundState(
                event_id=str(data.get("id") or refund_id),
                status=status,
                provider_reference=order_id,
                refund_reference=provider_refund_reference,
                amount_minor=amount_minor,
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "PayPal refund reconciliation failed",
                status_code=503,
                retryable=True,
            ) from exc

    def verify_and_parse_webhook(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> ProviderEvent:
        del raw_body, headers
        raise ApplicationError(
            "RESOURCE_NOT_FOUND",
            "PayPal webhooks are not used by this checkout flow",
            status_code=404,
        )
