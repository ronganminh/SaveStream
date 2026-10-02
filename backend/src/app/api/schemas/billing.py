from __future__ import annotations

from datetime import datetime
from typing import Literal
from urllib.parse import urlparse

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Money(StrictModel):
    amount_minor: int = Field(ge=0)
    currency: str = Field(min_length=3, max_length=3)


class CreditPackageResponse(StrictModel):
    id: str
    name: str
    credits: int = Field(ge=1)
    price: Money
    active: bool


class CreditPackageListResponse(StrictModel):
    items: list[CreditPackageResponse]


class CreatePaymentOrderRequest(StrictModel):
    package_id: str


PaymentStatusValue = Literal[
    "created",
    "pending",
    "paid",
    "failed",
    "cancelled",
    "expired",
    "partially_refunded",
    "refunded",
]


class PaymentOrderResponse(StrictModel):
    id: str
    package_id: str
    status: PaymentStatusValue
    credits: int = Field(ge=1)
    amount: Money
    provider: str | None = None
    provider_reference: str | None = None
    created_at: datetime
    updated_at: datetime


class PaymentOrderListResponse(StrictModel):
    items: list[PaymentOrderResponse]
    pagination: Pagination


class CheckoutRequest(StrictModel):
    return_url: str = Field(min_length=1, max_length=2048)

    @field_validator("return_url")
    @classmethod
    def validate_return_url(cls, value: str) -> str:
        parsed = urlparse(value)
        if (
            parsed.scheme not in {"http", "https"}
            or not parsed.netloc
            or parsed.username
            or parsed.password
            or parsed.fragment
        ):
            raise ValueError(
                "return_url must be an absolute http(s) URL without credentials or fragment"
            )
        return value


class CheckoutResponse(StrictModel):
    checkout_url: str
    payment_order: PaymentOrderResponse
