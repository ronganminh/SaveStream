from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.api.schemas.recordings import Creator, Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class CreateLocalRecordingSessionRequest(StrictModel):
    watch_id: str
    device_id: str = Field(min_length=1, max_length=160)
    reward_id: str | None = None


class LocalRecordingStream(StrictModel):
    url: str
    format: Literal["flv", "hls"]
    headers: dict[str, str]


class LocalRecordingSessionStartResponse(StrictModel):
    session_id: str
    granted_seconds: int = Field(ge=1)
    lease_expires_at: datetime
    stream: LocalRecordingStream


class ExtendLocalRecordingSessionRequest(StrictModel):
    reward_id: str | None = None


LocalRecordingEndReason = Literal[
    "user_stopped",
    "live_ended",
    "free_minutes_exhausted",
    "storage_low",
    "interrupted",
    "error",
]
LocalRecordingStatus = Literal["completed", "partial", "recovered", "failed"]


class FinishLocalRecordingSessionRequest(StrictModel):
    recorded_seconds: int = Field(ge=0)
    size_bytes: int = Field(ge=0)
    end_reason: LocalRecordingEndReason
    status: LocalRecordingStatus


class LocalRecordingResponse(StrictModel):
    id: str
    watch_id: str
    creator: Creator
    device_id: str
    device_name: str
    started_at: datetime
    recorded_seconds: int = Field(ge=0)
    size_bytes: int = Field(ge=0)
    status: LocalRecordingStatus


class LocalRecordingListResponse(StrictModel):
    items: list[LocalRecordingResponse]
    pagination: Pagination


RewardPurpose = Literal["local_minutes", "local_slot"]
RewardStatus = Literal["pending", "valid", "invalid", "expired"]


class CreateRewardRequest(StrictModel):
    purpose: RewardPurpose
    session_id: str | None = None


class RewardCreateResponse(StrictModel):
    reward_id: str
    ssv_user_id: str
    ssv_custom_data: str
    expires_at: datetime


class RewardStatusResponse(StrictModel):
    reward_id: str
    status: RewardStatus
