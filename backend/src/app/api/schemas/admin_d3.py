from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminRecordingReasonRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


class AdminRecordingRetentionRequest(AdminRecordingReasonRequest):
    expires_at: datetime


class AdminPlaybackAccessResponse(StrictModel):
    url: str
    expires_at: datetime
    artifact_id: str


class AdminQueueItemResponse(StrictModel):
    recording_id: str
    user_id: str
    user_email: str
    channel: str
    waiting_since: datetime
    queue_position: int


class AdminQueueResponse(StrictModel):
    items: list[AdminQueueItemResponse]
    missed_today: int = Field(ge=0)
    next_cursor: str | None
    has_more: bool


class AdminWatchChannelResponse(StrictModel):
    source_type: str
    channel: str
    followers: int = Field(ge=0)
    auto_record_count: int = Field(ge=0)
    paused_count: int = Field(ge=0)
    failing_count: int = Field(ge=0)
    max_failure_count: int = Field(ge=0)
    last_checked_at: datetime | None
    last_error: str | None


class AdminWatchChannelListResponse(StrictModel):
    items: list[AdminWatchChannelResponse]
    next_cursor: str | None
    has_more: bool


class AdminDetectorHourlyResponse(StrictModel):
    hour: datetime
    checks: int = Field(ge=0)
    failures: int = Field(ge=0)
    failure_rate: float | None = Field(default=None, ge=0, le=1)
    average_latency_ms: int | None = Field(default=None, ge=0)


class AdminDetectorMetricsResponse(StrictModel):
    last_run_at: datetime | None
    last_latency_ms: int | None = Field(default=None, ge=0)
    average_latency_ms_1h: int | None = Field(default=None, ge=0)
    failure_rate_1h: float | None = Field(default=None, ge=0, le=1)
    hourly: list[AdminDetectorHourlyResponse]


class AdminCapacityHourlyResponse(StrictModel):
    hour: datetime
    max_concurrent: int = Field(ge=0)
    limit: int = Field(gt=0)


class AdminCapacityResponse(StrictModel):
    current_in_use: int = Field(ge=0)
    global_limit: int = Field(gt=0)
    hourly: list[AdminCapacityHourlyResponse]
