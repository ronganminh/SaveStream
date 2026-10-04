from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Protocol


@dataclass(frozen=True, slots=True)
class CheckoutSession:
    provider_reference: str
    checkout_url: str


@dataclass(frozen=True, slots=True)
class RefundSession:
    provider_refund_reference: str


@dataclass(frozen=True, slots=True)
class ProviderEvent:
    event_id: str
    event_type: str
    provider_reference: str
    payment_order_id: str | None = None
    amount_minor: int | None = None
    currency: str | None = None
    refund_reference: str | None = None


@dataclass(frozen=True, slots=True)
class ProviderPaymentState:
    event_id: str
    status: str
    provider_reference: str
    amount_minor: int
    currency: str


@dataclass(frozen=True, slots=True)
class ProviderRefundState:
    event_id: str
    status: str
    provider_reference: str
    refund_reference: str
    amount_minor: int


class PaymentProvider(Protocol):
    name: str

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
        variant_id: str | None = None,
    ) -> CheckoutSession: ...

    async def create_refund(
        self,
        *,
        refund_id: str,
        provider_reference: str,
        amount_minor: int,
        currency: str,
    ) -> RefundSession: ...

    async def retrieve_payment(
        self,
        provider_reference: str,
    ) -> ProviderPaymentState | None: ...

    async def retrieve_refund(
        self,
        provider_refund_reference: str,
    ) -> ProviderRefundState | None: ...

    def verify_and_parse_webhook(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> ProviderEvent: ...
