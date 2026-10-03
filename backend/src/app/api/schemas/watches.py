from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, model_validator

from app.api.schemas.recordings import Creator, Pagination, Source


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


WatchStatusValue = Literal[
    "active",
    "paused",
    "paused_insufficient_credit",
    "paused_error",
    "disabled",
]
LiveStatusValue = Literal["unknown", "offline", "live"]
AutoRecordStateValue = Literal["off", "active", "paused_no_cloud_minutes"]


class WatchResponse(StrictModel):
    id: str
    source: Source
    creator: Creator | None
    status: WatchStatusValue
    live_status: LiveStatusValue
    auto_record: bool
    auto_record_state: AutoRecordStateValue = "off"
    last_checked_at: datetime | None
    next_check_at: datetime | None
    last_live_at: datetime | None
    created_at: datetime
    updated_at: datetime


class CreateWatchRequest(StrictModel):
    source: Source
    auto_record: bool


class UpdateWatchRequest(StrictModel):
    auto_record: bool | None = None
    status: Literal["active", "paused", "disabled"] | None = None

    @model_validator(mode="after")
    def at_least_one_field(self) -> "UpdateWatchRequest":
        if self.auto_record is None and self.status is None:
            raise ValueError("At least one Watch field must be provided")
        return self


class WatchListResponse(StrictModel):
    items: list[WatchResponse]
    pagination: Pagination
