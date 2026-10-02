from __future__ import annotations

from typing import Mapping, NoReturn

from app.domain.common.errors import ApplicationError

from .base import (
    CheckoutSession,
    ProviderEvent,
    ProviderPaymentState,
    ProviderRefundState,
    RefundSession,
)


def _payments_disabled() -> NoReturn:
    raise ApplicationError(
        "SERVICE_UNAVAILABLE",
        "Payments are not enabled",
        status_code=503,
    )


class DisabledPaymentProvider:
    """Launch mode without a live payment provider.

    Read-only billing endpoints keep working; anything that would reach a
    provider fails closed and no credits can be granted.
    """

    name = "disabled"

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
    ) -> CheckoutSession:
        del order_id, amount_minor, currency, return_url
        _payments_disabled()

    async def create_refund(
        self,
        *,
        refund_id: str,
        provider_reference: str,
        amount_minor: int,
        currency: str,
    ) -> RefundSession:
        del refund_id, provider_reference, amount_minor, currency
        _payments_disabled()

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
        del raw_body, headers
        _payments_disabled()
