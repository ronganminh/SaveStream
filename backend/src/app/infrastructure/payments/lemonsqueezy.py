from __future__ import annotations

import hashlib
import hmac
import json
from typing import Mapping

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


class LemonSqueezyPaymentProvider:
    name = "lemonsqueezy"

    def __init__(self, settings: AppSettings) -> None:
        self.settings = settings
        self.base_url = (
            settings.payment_provider_base_url
            or "https://api.lemonsqueezy.com/v1"
        ).rstrip("/")

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.settings.payment_provider_api_key}",
            "Accept": "application/vnd.api+json",
            "Content-Type": "application/vnd.api+json",
        }

    @staticmethod
    def _resource(payload: object) -> dict[str, object]:
        if not isinstance(payload, dict):
            raise ValueError("invalid Lemon Squeezy response")
        data = payload.get("data", payload)
        if not isinstance(data, dict):
            raise ValueError("invalid Lemon Squeezy response")
        return data

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
    ) -> CheckoutSession:
        del currency
        payload = {
            "data": {
                "type": "checkouts",
                "attributes": {
                    "custom_price": amount_minor,
                    "product_options": {
                        "redirect_url": return_url,
                    },
                    "checkout_options": {
                        "discount": False,
                    },
                    "checkout_data": {
                        "custom": {
                            "payment_order_id": order_id,
                        }
                    },
                },
                "relationships": {
                    "store": {
                        "data": {
                            "type": "stores",
                            "id": self.settings.lemon_squeezy_store_id,
                        }
                    },
                    "variant": {
                        "data": {
                            "type": "variants",
                            "id": self.settings.lemon_squeezy_variant_id,
                        }
                    },
                },
            }
        }
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.post(
                    f"{self.base_url}/checkouts",
                    headers=self._headers(),
                    json=payload,
                )
                response.raise_for_status()
                resource = self._resource(response.json())
            attributes = resource["attributes"]
            if not isinstance(attributes, dict):
                raise ValueError("invalid checkout attributes")
            return CheckoutSession(
                provider_reference=f"checkout:{resource['id']}",
                checkout_url=str(attributes["url"]),
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Lemon Squeezy checkout failed",
                status_code=502,
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
        del currency
        if provider_reference.startswith("checkout:"):
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Lemon Squeezy order is not ready for refund",
                status_code=409,
                retryable=True,
            )
        payload = {
            "data": {
                "type": "orders",
                "id": provider_reference,
                "attributes": {
                    "amount": amount_minor,
                },
            }
        }
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.post(
                    f"{self.base_url}/orders/{provider_reference}/refund",
                    headers=self._headers(),
                    json=payload,
                )
                response.raise_for_status()
                resource = self._resource(response.json())
            attributes = resource["attributes"]
            if not isinstance(attributes, dict):
                raise ValueError("invalid refund attributes")
            refunded_total = int(attributes["refunded_amount"])
            reference = (
                f"lemonsqueezy:{provider_reference}:"
                f"{refunded_total}:{amount_minor}:{refund_id}"
            )
            return RefundSession(provider_refund_reference=reference)
        except ApplicationError:
            raise
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Lemon Squeezy refund failed",
                status_code=502,
                retryable=True,
            ) from exc

    async def retrieve_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState | None:
        if provider_reference.startswith("checkout:"):
            return None
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.get(
                    f"{self.base_url}/orders/{provider_reference}",
                    headers=self._headers(),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                resource = self._resource(response.json())
            attributes = resource["attributes"]
            if not isinstance(attributes, dict):
                raise ValueError("invalid order attributes")
            status = str(attributes["status"])
            normalized = {
                "pending": "pending",
                "failed": "failed",
                "fraudulent": "failed",
                "paid": "paid",
                "partial_refund": "paid",
                "refunded": "paid",
            }.get(status, "pending")
            event_id = str(
                attributes.get("identifier")
                or f"lemonsqueezy-order-{provider_reference}"
            )
            return ProviderPaymentState(
                event_id=event_id,
                status=normalized,
                provider_reference=provider_reference,
                amount_minor=int(attributes["subtotal"]),
                currency=str(attributes["currency"]).upper(),
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Lemon Squeezy reconciliation failed",
                status_code=503,
                retryable=True,
            ) from exc

    async def retrieve_refund(
        self,
        provider_refund_reference: str,
    ) -> ProviderRefundState | None:
        parts = provider_refund_reference.split(":", 4)
        if len(parts) != 5 or parts[0] != "lemonsqueezy":
            return None
        _, order_id, target_raw, amount_raw, _ = parts
        try:
            target = int(target_raw)
            amount = int(amount_raw)
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.get(
                    f"{self.base_url}/orders/{order_id}",
                    headers=self._headers(),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                resource = self._resource(response.json())
            attributes = resource["attributes"]
            if not isinstance(attributes, dict):
                raise ValueError("invalid order attributes")
            refunded_total = int(attributes.get("refunded_amount", 0))
            status = "succeeded" if refunded_total >= target else "pending"
            return ProviderRefundState(
                event_id=(
                    f"refund:{order_id}:{target}:"
                    f"{attributes.get('updated_at', '')}"
                ),
                status=status,
                provider_reference=order_id,
                refund_reference=provider_refund_reference,
                amount_minor=amount,
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Lemon Squeezy refund reconciliation failed",
                status_code=503,
                retryable=True,
            ) from exc

    def verify_and_parse_webhook(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> ProviderEvent:
        signature = next(
            (
                value.strip()
                for key, value in headers.items()
                if key.lower() == "x-signature"
            ),
            "",
        )
        expected = hmac.new(
            self.settings.payment_webhook_secret.encode("utf-8"),
            raw_body,
            hashlib.sha256,
        ).hexdigest()
        if not signature or not hmac.compare_digest(signature, expected):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid Lemon Squeezy webhook signature",
                status_code=400,
            )

        try:
            payload = json.loads(raw_body.decode("utf-8"))
            meta = payload["meta"]
            data = payload["data"]
            attributes = data["attributes"]
            event_name = str(meta["event_name"])
            order_id = str(data["id"])
            custom_data = meta.get("custom_data") or {}
            payment_order_id = (
                str(custom_data["payment_order_id"])
                if custom_data.get("payment_order_id") is not None
                else None
            )
            subtotal = int(attributes["subtotal"])
            currency = str(attributes["currency"]).upper()
            refunded_amount = int(attributes.get("refunded_amount", 0))
        except (
            UnicodeDecodeError,
            json.JSONDecodeError,
            KeyError,
            TypeError,
            ValueError,
        ) as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid Lemon Squeezy webhook payload",
                status_code=400,
            ) from exc

        if event_name == "order_created":
            status = str(attributes.get("status", "paid"))
            event_type = {
                "paid": "payment.paid",
                "failed": "payment.failed",
                "fraudulent": "payment.failed",
                "pending": "payment.pending",
            }.get(status, "payment.paid")
            event_id = f"order_created:{order_id}"
        elif event_name == "order_refunded":
            event_type = "payment.updated"
            event_id = f"order_refunded:{order_id}:{refunded_amount}"
        else:
            event_type = "payment.updated"
            event_id = f"{event_name}:{order_id}"

        return ProviderEvent(
            event_id=event_id,
            event_type=event_type,
            provider_reference=order_id,
            payment_order_id=payment_order_id,
            amount_minor=subtotal,
            currency=currency,
        )
