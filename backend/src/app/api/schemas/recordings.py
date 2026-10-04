from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Source(StrictModel):
    type: Literal["username", "room_id", "url"]
    value: str = Field(min_length=1, max_length=2048)


class Creator(StrictModel):
    platform: Literal["tiktok"] = "tiktok"
    username: str
    display_name: str
    avatar_url: str | None = None


class LiveStatusRequest(StrictModel):
    source: Source


class LiveStatusResponse(StrictModel):
    source: Source
    creator: Creator | None
    live_status: Literal["unknown", "offline", "live"]
    room_id: str | None
    checked_at: datetime


RecordingStatusValue = Literal[
    "queued",
    "resolving",
    "waiting_live",
    "recording",
    "processing",
    "uploading",
    "completed",
    "failed",
    "stop_requested",
    "stopped",
    "waiting_for_cloud_slot",
    "missed_no_cloud_slot",
]


class RecordingActions(StrictModel):
    can_stop: bool
    can_retry: bool
    can_delete: bool


class RecordingError(StrictModel):
    code: str
    message: str
    retryable: bool


class RecordingResponse(StrictModel):
    id: str
    source: Source
    creator: Creator | None = None
    status: RecordingStatusValue
    started_at: datetime | None
    ended_at: datetime | None
    duration_seconds: int = Field(ge=0)
    bytes_recorded: int = Field(ge=0)
    estimated_max_cost: int = Field(ge=0)
    actual_cost: int | None = Field(default=None, ge=0)
    credit_reservation_id: str | None
    actions: RecordingActions
    error: RecordingError | None
    created_at: datetime
    updated_at: datetime
    expires_at: datetime | None = None
    engine: Literal["cloud"] = "cloud"
    minutes_charged: int = Field(default=0, ge=0)
    queue_position: int | None = Field(default=None, ge=1)


class CreateRecordingRequest(StrictModel):
    source: Source
    max_duration_seconds: int | None = Field(default=None, ge=1)
    quality: Literal["best"] = "best"
    container: Literal["mp4"] = "mp4"


class Pagination(StrictModel):
    next_cursor: str | None
    has_more: bool


class RecordingListResponse(StrictModel):
    items: list[RecordingResponse]
    pagination: Pagination


class RecordingProgressData(StrictModel):
    status: RecordingStatusValue
    duration_seconds: int = Field(ge=0)
    bytes_recorded: int = Field(ge=0)


class RecordingEventResponse(StrictModel):
    id: str
    sequence: int = Field(ge=0)
    type: str
    recording_id: str
    created_at: datetime
    data: RecordingProgressData


class ArtifactResponse(StrictModel):
    id: str
    recording_id: str
    kind: Literal["video"] = "video"
    container: Literal["mp4"] = "mp4"
    size_bytes: int = Field(ge=0)
    checksum_sha256: str
    created_at: datetime


class ArtifactsResponse(StrictModel):
    items: list[ArtifactResponse]


class DownloadUrlResponse(StrictModel):
    url: str
    expires_at: datetime
