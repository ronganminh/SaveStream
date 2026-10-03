from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.billing import PaymentOrderResponse
from app.api.schemas.credits import CreditBalanceResponse, CreditTransactionResponse
from app.api.schemas.recordings import Pagination, RecordingResponse
from app.api.schemas.watches import WatchResponse


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
    plan: Literal["free", "pro"] | None = None
    cloud_minutes_available: int | None = None
    latest_purchase_provider: str | None = None


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



class AdminSupportActionRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


class AdminUserProfileUpdateRequest(StrictModel):
    display_name: str | None = Field(default=None, max_length=160)
    reason: str = Field(min_length=3, max_length=500)


class AdminUserNoteRequest(StrictModel):
    body: str = Field(min_length=1, max_length=4000)
    reason: str = Field(min_length=3, max_length=500)


class AdminUserNoteResponse(StrictModel):
    id: str
    user_id: str
    author_user_id: str | None
    body: str
    created_at: datetime
    updated_at: datetime


class AdminUserSessionResponse(StrictModel):
    id: str
    client_type: str
    user_agent: str | None
    ip_hint: str | None
    created_at: datetime
    last_seen_at: datetime
    expires_at: datetime
    revoked_at: datetime | None
    revoked_reason: str | None


class AdminUserNotificationResponse(StrictModel):
    id: str
    kind: str
    title: str
    body: str
    resource_type: str | None
    resource_id: str | None
    read_at: datetime | None
    created_at: datetime


class AdminEntitlementResponse(StrictModel):
    plan: Literal["free", "pro"]
    has_purchased: bool
    cloud_minutes_available: int
    max_watches: int
    max_concurrent_cloud_recordings: int
    cloud_retention_days: int
    watch_count: int


class AdminUserDetailResponse(StrictModel):
    user: AdminUserResponse
    entitlement: AdminEntitlementResponse
    balance: CreditBalanceResponse
    watches: list[WatchResponse]
    recordings: list[RecordingResponse]
    payments: list[PaymentOrderResponse]
    ledger: list[CreditTransactionResponse]
    sessions: list[AdminUserSessionResponse]
    notifications: list[AdminUserNotificationResponse]
    notes: list[AdminUserNoteResponse]
    audit: list[AuditLogResponse]


class AdminViewAsUserResponse(StrictModel):
    user: AdminUserResponse
    entitlement: AdminEntitlementResponse
    balance: CreditBalanceResponse
    watches: list[WatchResponse]
    recordings: list[RecordingResponse]


class AdminPrivacyRequestResponse(StrictModel):
    id: str
    user_id: str
    email: str
    kind: Literal["delete", "export"]
    status: Literal["pending", "completed", "cancelled"]
    requested_at: datetime
    completed_at: datetime | None = None
    cancelled_at: datetime | None = None


class AdminPrivacyRequestListResponse(StrictModel):
    items: list[AdminPrivacyRequestResponse]


class AdminSearchHit(StrictModel):
    type: Literal["user", "payment_order", "recording", "request"]
    id: str
    label: str
    detail: str | None = None
    href: str


class AdminSearchResponse(StrictModel):
    items: list[AdminSearchHit]


class AdminActionResponse(StrictModel):
    message: str
