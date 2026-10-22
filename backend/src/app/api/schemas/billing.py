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


class StoreProductIds(StrictModel):
    app_store: str | None = None
    google_play: str | None = None


class CreditPackageResponse(StrictModel):
    id: str
    name: str
    credits: int = Field(ge=1)
    price: Money
    active: bool
    store_product_ids: StoreProductIds | None = None
    cloud_minutes: int | None = Field(default=None, ge=1)
    # Highlight this pack ("Most popular"). Config driven
    # (SAVESTREAM_FEATURED_PACKAGE_CODES); never changes the price.
    featured: bool = False


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
    # Opaque order reference. For Google Play it is a hash of the purchase
    # token ("token:<sha256>"), not Play's order id: see store_order_id.
    provider_reference: str | None = None
    # Google Play orderId ("GPA.…") as Play reported it; null for web orders,
    # promo-code purchases and older orders not re-verified since.
    store_order_id: str | None = None
    # The store price the app showed when it bought, as the app reported it
    # (micros, e.g. 24990000 = 24.99, and ISO 4217 currency). Display only:
    # not verified with Google; amount is the catalog list price.
    client_price_amount_micros: int | None = Field(default=None, ge=0)
    client_price_currency: str | None = Field(default=None, min_length=3, max_length=3)
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


class CapturePaymentRequest(StrictModel):
    provider_order_id: str = Field(min_length=1, max_length=255)


StorePurchasePlatform = Literal["app_store", "google_play"]
StorePurchaseStatus = Literal["credited", "pending", "payment_pending", "rejected"]


class StorePurchaseRequest(StrictModel):
    platform: StorePurchasePlatform
    product_id: str = Field(min_length=1, max_length=160)
    transaction_id: str = Field(min_length=1, max_length=255)
    receipt: str = Field(min_length=1)
    # Optional, display only: the price Google Play showed the user
    # (ProductDetails priceAmountMicros / priceCurrencyCode). Stored on the
    # payment order as client_price_*; never verified or used for accounting.
    price_amount_micros: int | None = Field(default=None, ge=0, le=10**13)
    price_currency_code: str | None = Field(
        default=None, min_length=3, max_length=3, pattern=r"^[A-Za-z]{3}$"
    )


class StorePurchaseResponse(StrictModel):
    status: StorePurchaseStatus
    payment_order_id: str
    cloud_minutes_added: int = Field(ge=0)
    cloud_minutes_available: int = Field(ge=0)


class PublicRecordingRate(StrictModel):
    unit_seconds: int = Field(ge=1)
    credits_per_unit: int = Field(ge=0)
    minimum_credits: int = Field(ge=0)


class PublicCreditPackage(StrictModel):
    id: str
    code: str
    name: str
    credits: int = Field(ge=1)
    price: Money
    recording_minutes: int | None = Field(default=None, ge=0)
    featured: bool = False


class PublicCheckoutChannels(StrictModel):
    """Purchase channels that are open right now (runtime flag + provider)."""

    web: bool = False
    app_store: bool = False
    google_play: bool = False


class PublicPricingResponse(StrictModel):
    packages: list[PublicCreditPackage]
    recording_rate: PublicRecordingRate | None
    signup_credits: int = Field(ge=0)
    max_channels_per_user: int | None = Field(default=None, ge=1)
    free_max_channels_per_user: int | None = Field(default=None, ge=1)
    max_concurrent_recordings_per_user: int | None = Field(default=None, ge=1)
    recording_retention_days: int | None = Field(default=None, ge=1)
    trial_recording_retention_days: int | None = Field(default=None, ge=1)
    checkout: PublicCheckoutChannels = Field(default_factory=PublicCheckoutChannels)
