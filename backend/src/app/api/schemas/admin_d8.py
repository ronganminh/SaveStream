from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminComplaintCreateRequest(StrictModel):
    kind: Literal["copyright", "abuse"]
    complainant_name: str = Field(min_length=1, max_length=200)
    complainant_email: str = Field(min_length=3, max_length=320)
    channel_source_type: Literal["username", "room_id", "url"] | None = None
    channel_source_value: str | None = Field(default=None, max_length=2048)
    recording_id: str | None = None
    summary: str = Field(min_length=3, max_length=240)
    body: str = Field(min_length=3, max_length=20_000)

    @model_validator(mode="after")
    def validate_target(self):
        has_channel = bool(self.channel_source_type and self.channel_source_value)
        if not has_channel and not self.recording_id:
            raise ValueError("A channel or recording target is required")
        if bool(self.channel_source_type) != bool(self.channel_source_value):
            raise ValueError("Channel source type and value must be provided together")
        return self


class AdminComplaintUpdateRequest(StrictModel):
    status: Literal["new", "reviewing", "resolved", "rejected"]
    assigned_to_user_id: str | None = None
    reason: str = Field(min_length=3, max_length=500)


class AdminComplaintEventResponse(StrictModel):
    id: str
    action: str
    actor_user_id: str | None
    note: str | None
    metadata: dict[str, object]
    created_at: datetime


class AdminComplaintResponse(StrictModel):
    id: str
    kind: Literal["copyright", "abuse"]
    complainant_name: str
    complainant_email: str
    channel_source_type: str | None
    channel_source_value: str | None
    recording_id: str | None
    summary: str
    body: str
    status: Literal["new", "reviewing", "resolved", "rejected"]
    assigned_to_user_id: str | None
    created_by_user_id: str | None
    resolved_at: datetime | None
    created_at: datetime
    updated_at: datetime
    timeline: list[AdminComplaintEventResponse] = Field(default_factory=list)


class AdminComplaintListResponse(StrictModel):
    items: list[AdminComplaintResponse]
    next_cursor: str | None
    has_more: bool


class AdminCreatorBlockRequest(StrictModel):
    source_type: Literal["username", "room_id", "url"]
    source_value: str = Field(min_length=1, max_length=2048)
    complaint_id: str | None = None
    reason: str = Field(min_length=3, max_length=500)


class AdminCreatorUnblockRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)


class AdminCreatorBlockResponse(StrictModel):
    id: str
    source_type: str
    source_value: str
    complaint_id: str | None
    reason: str
    blocked_by_user_id: str | None
    active: bool
    unblocked_at: datetime | None
    unblock_reason: str | None
    created_at: datetime
    stopped_recording_ids: list[str] = Field(default_factory=list)
    paused_watch_ids: list[str] = Field(default_factory=list)
