from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.api.schemas.billing import PaymentStatusValue
from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


PurchaseChannel = Literal["web", "app_store", "google_play"]
RefundMode = Literal["admin_web", "store_managed"]


class AdminPaymentOrderResponse(StrictModel):
    id: str
    user_id: str
    user_email: str
    package_id: str
    package_code: str
    package_name: str
    status: PaymentStatusValue
    purchase_channel: PurchaseChannel
    provider: str | None
    provider_transaction_id: str | None
    credits: int = Field(ge=1)
    amount_minor: int = Field(ge=0)
    currency: str
    refunded_credits: int = Field(ge=0)
    refunded_amount_minor: int = Field(ge=0)
    gross_usd_minor: int | None = Field(default=None, ge=0)
    estimated_store_fee_minor: int | None = Field(default=None, ge=0)
    estimated_store_fee_rate_bps: int | None = Field(default=None, ge=0)
    refund_mode: RefundMode
    paid_at: datetime | None
    created_at: datetime
    updated_at: datetime


class AdminPaymentOrderListResponse(StrictModel):
    items: list[AdminPaymentOrderResponse]
    pagination: Pagination


class AdminPaymentTimelineItem(StrictModel):
    at: datetime
    event: str
    status: str | None = None
    detail: str | None = None


class AdminPaymentOrderDetailResponse(StrictModel):
    order: AdminPaymentOrderResponse
    timeline: list[AdminPaymentTimelineItem]


class AdminRefundPreviewResponse(StrictModel):
    payment_order_id: str
    amount_minor: int = Field(gt=0)
    corresponding_credits: int = Field(ge=0)
    deducted_credits: int = Field(ge=0)
    balance_available: int = Field(ge=0)
    remaining_refundable_amount_minor: int = Field(ge=0)
    remaining_refundable_credits: int = Field(ge=0)


class AdminReconcilePaymentResponse(StrictModel):
    payment_order_id: str
    action: Literal[
        "no_change",
        "credits_repaired",
        "provider_state_applied",
        "still_pending",
    ]
    status: PaymentStatusValue


class AdminStuckPaymentResponse(StrictModel):
    order: AdminPaymentOrderResponse
    reason: Literal["pending_too_long", "paid_missing_credit"]


class AdminStuckPaymentListResponse(StrictModel):
    items: list[AdminStuckPaymentResponse]
    pagination: Pagination


LedgerCategory = Literal["purchase", "spend", "refund", "adjustment", "gift"]


class AdminLedgerEntryResponse(StrictModel):
    id: str
    user_id: str
    user_email: str
    category: LedgerCategory
    type: str
    amount: int
    balance_after: int
    reference_type: str
    reference_id: str | None
    reason: str | None
    counts_as_purchase: bool
    created_at: datetime


class AdminLedgerListResponse(StrictModel):
    items: list[AdminLedgerEntryResponse]
    pagination: Pagination


class AdminStuckReservationResponse(StrictModel):
    id: str
    user_id: str
    recording_id: str
    recording_status: str
    reserved: int = Field(ge=0)
    settled: int = Field(ge=0)
    released: int = Field(ge=0)
    remaining_reserved: int = Field(ge=0)
    created_at: datetime


class AdminStuckReservationListResponse(StrictModel):
    items: list[AdminStuckReservationResponse]
    pagination: Pagination


class AdminReservationReleaseResponse(StrictModel):
    reservation: AdminStuckReservationResponse
    released_credits: int = Field(ge=0)
