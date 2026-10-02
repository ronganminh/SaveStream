from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


NotificationKind = Literal[
    "recording_started",
    "recording_ready",
    "recording_failed",
]


class NotificationResponse(StrictModel):
    id: str
    type: NotificationKind
    title: str
    body: str
    read: bool
    resource_type: Literal["recording"] | None
    resource_id: str | None
    created_at: datetime


class NotificationListResponse(StrictModel):
    items: list[NotificationResponse]
    pagination: Pagination


class NotificationUpdateRequest(StrictModel):
    read: bool = True


class MarkAllReadResponse(StrictModel):
    updated: int


class NotificationPreferenceResponse(StrictModel):
    recording_started: bool
    recording_ready: bool
    recording_failed: bool
    email_supported: Literal[False] = False
    updated_at: datetime | None


class UpdateNotificationPreferencesRequest(StrictModel):
    recording_started: bool | None = None
    recording_ready: bool | None = None
    recording_failed: bool | None = None
