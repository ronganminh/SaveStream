from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.billing import PaymentOrderResponse
from app.api.schemas.recordings import Pagination, RecordingResponse
from app.api.schemas.credits import CreditTransactionResponse


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminUserResponse(StrictModel):
    id: str
    email: str
    display_name: str | None
    role: Literal["user", "admin"]
    is_active: bool
    email_verified_at: datetime | None
    deletion_requested_at: datetime | None
    created_at: datetime
    updated_at: datetime


class AdminUserListResponse(StrictModel):
    items: list[AdminUserResponse]
    pagination: Pagination


class AdminUserUpdateRequest(StrictModel):
    role: Literal["user", "admin"] | None = None
    is_active: bool | None = None

    @model_validator(mode="after")
    def at_least_one_field(self) -> "AdminUserUpdateRequest":
        if self.role is None and self.is_active is None:
            raise ValueError("At least one field must be provided")
        return self


class AdminRecordingListResponse(StrictModel):
    items: list[RecordingResponse]
    pagination: Pagination


class AdminRetryRecordingResponse(StrictModel):
    original_recording_id: str
    recording: RecordingResponse


class AdminPaymentListResponse(StrictModel):
    items: list[PaymentOrderResponse]
    pagination: Pagination


class AdminCreditAdjustmentRequest(StrictModel):
    user_id: str
    amount: int
    reason: str = Field(min_length=3, max_length=500)


class AdminCreditAdjustmentResponse(StrictModel):
    transaction: CreditTransactionResponse


class AdminRefundRequest(StrictModel):
    amount_minor: int = Field(gt=0)
    credits: int = Field(gt=0)


class AdminRefundResponse(StrictModel):
    id: str
    payment_order_id: str
    status: str
    credits: int
    amount_minor: int
    provider: str | None
    provider_refund_reference: str | None
    created_at: datetime


class AuditLogResponse(StrictModel):
    id: str
    actor_user_id: str | None
    action: str
    resource_type: str | None
    resource_id: str | None
    request_id: str | None
    ip_address: str | None
    user_agent: str | None
    details: dict[str, object]
    created_at: datetime


class AuditLogListResponse(StrictModel):
    items: list[AuditLogResponse]
    pagination: Pagination
