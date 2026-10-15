from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


NotificationKind = Literal[
    "recording_started",
    "recording_ready",
    "recording_failed",
    "creator_live",
    "recording_missed",
    "recording_expiring",
    "cloud_minutes_exhausted",
    "credits_low",
    "free_minutes_low",
    "purchase_completed",
    "admin_system",
    "admin_marketing",
]


class NotificationResponse(StrictModel):
    id: str
    type: NotificationKind
    title: str
    body: str
    read: bool
    resource_type: Literal["recording", "watch", "broadcast"] | None
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
    creator_live: bool = True
    recording_expiring: bool = True
    free_minutes_low: bool = True
    marketing: bool = False
    # Email copies; each email also has an unsubscribe link.
    email_creator_live: bool = True
    email_recording_ready: bool = True
    email_recording_failed: bool = True
    email_recording_expiring: bool = True
    email_credits_low: bool = True
    email_credits_exhausted: bool = True
    email_supported: bool = True
    updated_at: datetime | None


class UpdateNotificationPreferencesRequest(StrictModel):
    recording_started: bool | None = None
    recording_ready: bool | None = None
    recording_failed: bool | None = None
    creator_live: bool | None = None
    recording_expiring: bool | None = None
    free_minutes_low: bool | None = None
    marketing: bool | None = None
    email_creator_live: bool | None = None
    email_recording_ready: bool | None = None
    email_recording_failed: bool | None = None
    email_recording_expiring: bool | None = None
    email_credits_low: bool | None = None
    email_credits_exhausted: bool | None = None


class EmailUnsubscribeRequest(StrictModel):
    token: str = Field(min_length=10, max_length=512)


class EmailUnsubscribeResponse(StrictModel):
    preference: str
    label: str
