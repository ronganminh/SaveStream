from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminStoreTransactionResponse(StrictModel):
    id: str
    user_id: str
    user_email: str
    provider: Literal["app_store", "google_play"]
    provider_reference: str | None
    status: str
    verification_status: Literal["verified", "pending", "rejected"]
    rejection_reason: str | None
    credits: int = Field(ge=0)
    refunded_credits: int = Field(ge=0)
    paid_at: datetime | None
    updated_at: datetime


class AdminStoreTransactionListResponse(StrictModel):
    items: list[AdminStoreTransactionResponse]


class AdminLocalRecordingDailyResponse(StrictModel):
    day: date
    sessions: int = Field(ge=0)
    free_minutes_granted: int = Field(ge=0)
    free_minutes_used: int = Field(ge=0)
    auto_closed_sessions: int = Field(ge=0)


class AdminLocalRecordingMetricsResponse(StrictModel):
    days: list[AdminLocalRecordingDailyResponse]


class AdminLocalSessionResponse(StrictModel):
    id: str
    user_id: str
    creator_username: str
    device_id: str
    device_name: str
    status: str
    granted_seconds: int = Field(ge=0)
    free_granted_seconds: int = Field(ge=0)
    recorded_seconds: int = Field(ge=0)
    started_at: datetime
    lease_expires_at: datetime
    end_reason: str | None
    auto_closed: bool


class AdminLocalSessionListResponse(StrictModel):
    items: list[AdminLocalSessionResponse]


class AdminRewardDailyResponse(StrictModel):
    day: date
    valid: int = Field(ge=0)
    invalid: int = Field(ge=0)
    pending: int = Field(ge=0)
    expired: int = Field(ge=0)


class AdminRewardRiskUserResponse(StrictModel):
    user_id: str
    user_email: str
    valid_count: int = Field(ge=0)
    invalid_count: int = Field(ge=0)
    invalid_ratio: float = Field(ge=0, le=1)
    invalid_streak: int = Field(ge=0)
    locked_until: datetime | None


class AdminRewardMetricsResponse(StrictModel):
    days: list[AdminRewardDailyResponse]
    locked_accounts: int = Field(ge=0)
    high_invalid_users: list[AdminRewardRiskUserResponse]


class AdminRewardUnlockRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


class AdminRewardUnlockResponse(StrictModel):
    user_id: str
    unlocked: bool
    previous_locked_until: datetime | None
    previous_invalid_streak: int = Field(ge=0)


class AdminDeviceDistributionRow(StrictModel):
    platform: str
    app_version: str
    devices: int = Field(ge=0)
    active_push_tokens: int = Field(ge=0)
    removed_push_tokens: int = Field(ge=0)


class AdminDeviceDistributionResponse(StrictModel):
    items: list[AdminDeviceDistributionRow]
