from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminStorageDayResponse(StrictModel):
    day: str
    bytes: int


class AdminStorageUserResponse(StrictModel):
    user_id: str
    email: str
    bytes: int


class AdminStorageCleanupResponse(StrictModel):
    run_id: str
    created_at: datetime
    deleted_count: int
    scanned_count: int


class AdminStorageSummaryResponse(StrictModel):
    total_bytes: int
    by_user: list[AdminStorageUserResponse]
    daily_trend: list[AdminStorageDayResponse]
    latest_cleanup: AdminStorageCleanupResponse | None


class AdminOrphanScanRequest(StrictModel):
    limit: int = Field(default=1000, ge=1, le=5000)
    reason: str = Field(min_length=3, max_length=500)


class AdminStorageRunResponse(StrictModel):
    id: str
    kind: str
    status: str
    scanned_count: int
    orphan_count: int
    deleted_count: int
    orphan_keys: list[str]
    truncated: bool
    error: str | None
    created_at: datetime
    started_at: datetime | None
    completed_at: datetime | None


class AdminReasonRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


class AdminEmailLogResponse(StrictModel):
    id: str
    user_id: str | None
    recipient_email: str
    kind: str
    subject: str
    status: str
    error: str | None
    attempts: int
    sent_at: datetime | None
    created_at: datetime


class AdminEmailLogListResponse(StrictModel):
    items: list[AdminEmailLogResponse]
    pagination: Pagination


class AdminEmailTemplateResponse(StrictModel):
    key: Literal["verify_email", "password_reset"]
    subject: str
    body: str
    overridden: bool
    updated_at: datetime | None


class AdminEmailTemplateUpdateRequest(StrictModel):
    subject: str = Field(min_length=1, max_length=240)
    body: str = Field(min_length=1, max_length=4000)
    reason: str = Field(min_length=3, max_length=500)


class AdminEmailPreviewResponse(StrictModel):
    subject: str
    text: str
    html: str


class AdminEmailTestRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


BroadcastKind = Literal["system", "marketing"]
BroadcastChannel = Literal["in_app", "push", "email"]


class AdminBroadcastPreviewRequest(StrictModel):
    kind: BroadcastKind
    channels: list[BroadcastChannel]

    @model_validator(mode="after")
    def validate_channels(self) -> "AdminBroadcastPreviewRequest":
        if not self.channels:
            raise ValueError("At least one delivery channel is required")
        if len(set(self.channels)) != len(self.channels):
            raise ValueError("Delivery channels must be unique")
        return self


class AdminBroadcastPreviewResponse(StrictModel):
    audience_count: int
    kind: BroadcastKind
    channels: list[BroadcastChannel]


class AdminBroadcastCreateRequest(AdminBroadcastPreviewRequest):
    title: str = Field(min_length=1, max_length=160)
    body: str = Field(min_length=1, max_length=4000)
    reason: str = Field(min_length=3, max_length=500)


class AdminBroadcastResponse(StrictModel):
    id: str
    kind: BroadcastKind
    title: str
    body: str
    channels: list[BroadcastChannel]
    status: str
    audience_count: int
    delivered_in_app: int
    delivered_push: int
    delivered_email: int
    failed_count: int
    reason: str
    created_at: datetime
    started_at: datetime | None
    completed_at: datetime | None


class AdminBroadcastListResponse(StrictModel):
    items: list[AdminBroadcastResponse]
    pagination: Pagination
