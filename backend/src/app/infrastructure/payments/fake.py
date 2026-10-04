from __future__ import annotations

from typing import Mapping
from urllib.parse import urlencode

from app.settings import AppSettings

from .base import (
    CheckoutSession,
    ProviderEvent,
    ProviderPaymentState,
    ProviderRefundState,
    RefundSession,
)
from .webhook import parse_standard_event, verify_hmac_sha256


class FakePaymentProvider:
    name = "fake"

    def __init__(self, settings: AppSettings) -> None:
        self.settings = settings

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
        variant_id: str | None = None,
    ) -> CheckoutSession:
        del amount_minor, currency, variant_id
        reference = f"fake_pay_{order_id}"
        query = urlencode(
            {
                "payment_order_id": order_id,
                "payment_reference": reference,
                "return_url": return_url,
            }
        )
        return CheckoutSession(
            provider_reference=reference,
            checkout_url=f"{self.settings.frontend_base_url}/fake-payment?{query}",
        )

    async def create_refund(
        self,
        *,
        refund_id: str,
        provider_reference: str,
        amount_minor: int,
        currency: str,
    ) -> RefundSession:
        del provider_reference, amount_minor, currency
        return RefundSession(
            provider_refund_reference=f"fake_refund_{refund_id}"
        )

    async def retrieve_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState | None:
        del provider_reference
        return None

    async def retrieve_refund(
        self,
        provider_refund_reference: str,
    ) -> ProviderRefundState | None:
        del provider_refund_reference
        return None

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
