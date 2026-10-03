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
    role: Literal["user", "owner", "support", "finance", "admin"]
    is_active: bool
    email_verified_at: datetime | None
    deletion_requested_at: datetime | None
    created_at: datetime
    updated_at: datetime


class AdminUserListResponse(StrictModel):
    items: list[AdminUserResponse]
    pagination: Pagination


class AdminUserUpdateRequest(StrictModel):
    role: Literal["user", "owner", "support", "finance", "admin"] | None = None
    is_active: bool | None = None
    reason: str | None = Field(default=None, min_length=3, max_length=500)

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
    reason: str = Field(min_length=3, max_length=500)


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
    actor_role: str | None
    reason: str | None
    before_state: dict[str, object] | None
    after_state: dict[str, object] | None
    details: dict[str, object]
    created_at: datetime


class AuditLogListResponse(StrictModel):
    items: list[AuditLogResponse]
    pagination: Pagination


class AdminMfaStatusResponse(StrictModel):
    enabled: bool
    verified: bool


class AdminMfaSetupResponse(StrictModel):
    secret: str
    otpauth_uri: str
    qr_svg: str
    recovery_codes: list[str]


class AdminMfaCodeRequest(StrictModel):
    code: str = Field(min_length=6, max_length=64)


class AdminStepUpRequest(StrictModel):
    password: str = Field(min_length=1, max_length=128)
    totp_code: str = Field(min_length=6, max_length=6)


class AdminStepUpResponse(StrictModel):
    token: str
    expires_at: datetime


class AdminRoleUpdateRequest(StrictModel):
    role: Literal["user", "owner", "support", "finance"]
    reason: str = Field(min_length=3, max_length=500)


class AdminMfaResetRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


class AdminAdminListResponse(StrictModel):
    items: list[AdminUserResponse]
    pagination: Pagination
