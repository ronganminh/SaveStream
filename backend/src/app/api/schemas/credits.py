from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CreditBalanceResponse(StrictModel):
    posted: int
    reserved: int
    available: int


class CreditTransactionResponse(StrictModel):
    id: str
    type: Literal["grant", "charge", "release", "adjustment", "refund"]
    amount: int
    balance_after: int
    reference_type: str
    reference_id: str | None
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
