from __future__ import annotations

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
from .webhook import parse_standard_event, verify_hmac_sha256


class ConfiguredHttpPaymentProvider:
    """Production-capable adapter for a configured provider gateway.

    The external gateway must expose SaveStream's small normalized payment
    protocol. A provider-specific adapter can replace this without changing
    domain/application code.
    """

    def __init__(self, settings: AppSettings) -> None:
        self.settings = settings
        self.name = settings.payment_provider

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.settings.payment_provider_api_key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
    ) -> CheckoutSession:
        payload = {
            "order_id": order_id,
            "amount_minor": amount_minor,
            "currency": currency,
            "return_url": return_url,
        }
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.post(
                    f"{self.settings.payment_provider_base_url}/checkouts",
                    headers=self._headers(),
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
            return CheckoutSession(
                provider_reference=str(data["reference"]),
                checkout_url=str(data["checkout_url"]),
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Payment provider checkout failed",
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
        payload = {
            "refund_id": refund_id,
            "payment_reference": provider_reference,
            "amount_minor": amount_minor,
            "currency": currency,
        }
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.post(
                    f"{self.settings.payment_provider_base_url}/refunds",
                    headers=self._headers(),
                    json=payload,
                )
                response.raise_for_status()
                data = response.json()
            return RefundSession(
                provider_refund_reference=str(data["refund_reference"])
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Payment provider refund failed",
                status_code=502,
                retryable=True,
            ) from exc

    async def retrieve_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState | None:
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.get(
                    (
                        f"{self.settings.payment_provider_base_url}/payments/"
                        f"{quote(provider_reference, safe='')}"
                    ),
                    headers=self._headers(),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                data = response.json()
            return ProviderPaymentState(
                event_id=str(data["event_id"]),
                status=str(data["status"]),
                provider_reference=provider_reference,
                amount_minor=int(data["amount_minor"]),
                currency=str(data["currency"]).upper(),
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Payment provider reconciliation failed",
                status_code=503,
                retryable=True,
            ) from exc

    async def retrieve_refund(
        self,
        provider_refund_reference: str,
    ) -> ProviderRefundState | None:
        try:
            async with httpx.AsyncClient(
                timeout=self.settings.payment_timeout_seconds
            ) as client:
                response = await client.get(
                    (
                        f"{self.settings.payment_provider_base_url}/refunds/"
                        f"{quote(provider_refund_reference, safe='')}"
                    ),
                    headers=self._headers(),
                )
                if response.status_code == 404:
                    return None
                response.raise_for_status()
                data = response.json()
            return ProviderRefundState(
                event_id=str(data["event_id"]),
                status=str(data["status"]),
                provider_reference=str(data["payment_reference"]),
                refund_reference=provider_refund_reference,
                amount_minor=int(data["amount_minor"]),
            )
        except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Payment provider refund reconciliation failed",
                status_code=503,
                retryable=True,
            ) from exc

    def verify_and_parse_webhook(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> ProviderEvent:
        verify_hmac_sha256(
            raw_body,
            headers,
            self.settings.payment_webhook_secret,
        )
        return parse_standard_event(raw_body)
