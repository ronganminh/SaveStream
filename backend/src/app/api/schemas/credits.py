from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CreditBalanceResponse(StrictModel):
    posted: int
    reserved: int
    available: int
    # Store refund that came after the credits were spent; recording is
    # blocked until a purchase pays it off.
    refund_debt: int = 0


class CreditTransactionResponse(StrictModel):
    id: str
    type: Literal["grant", "charge", "release", "adjustment", "refund"]
    amount: int
    balance_after: int
    reference_type: str
    reference_id: str | None
    # For a `release` entry: credits returned from the recording hold. The
    # entry's own amount is 0 because held credits never left the balance.
    released_credits: int | None = None
    # Entries for a payment order (purchase grant, store refund): Google
    # Play's orderId ("GPA.…", null for promo codes / web orders) and the
    # pack name.
    store_order_id: str | None = None
    package_name: str | None = None
    # Entries for a recording (hold, charge, release): the channel and how
    # long it recorded, so clients need not page through recordings.
    recording_channel_username: str | None = None
    recording_duration_seconds: int | None = Field(default=None, ge=0)
    created_at: datetime


class CreditTransactionListResponse(StrictModel):
    items: list[CreditTransactionResponse]
    pagination: Pagination


class CreditReservationResponse(StrictModel):
    id: str
    recording_id: str
    reserved: int
    settled: int
    released: int
    status: Literal["active", "settled", "released"]
    created_at: datetime


class CreditReservationListResponse(StrictModel):
    items: list[CreditReservationResponse]
    pagination: Pagination


class PricingResponse(StrictModel):
    version: str
    credit_unit: Literal["credit"] = "credit"
    rules: list[dict[str, Any]]


class RedeemPromotionRequest(StrictModel):
    code: str = Field(min_length=3, max_length=64)


class RedeemPromotionResponse(StrictModel):
    code: str
    cloud_minutes_added: int
    cloud_minutes_available: int
    counts_as_purchase: bool
