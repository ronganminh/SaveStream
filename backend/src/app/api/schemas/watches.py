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
AutoRecordStateValue = Literal[
    "off",
    "active",
    "paused_no_cloud_minutes",
    "waiting_for_cloud_slot",
]


class WatchResponse(StrictModel):
    id: str
    source: Source
    creator: Creator | None
    status: WatchStatusValue
    live_status: LiveStatusValue
    auto_record: bool
    auto_record_state: AutoRecordStateValue = "off"
    # Set only while a Recording job for this channel is actually in flight.
    active_recording_id: str | None = None
    active_recording_status: str | None = None
    notify_on_live: bool = True
    last_checked_at: datetime | None
    next_check_at: datetime | None
    last_live_at: datetime | None
    created_at: datetime
    updated_at: datetime
    # Set when the user confirmed they own, manage or may record the channel.
    owner_attested_at: datetime | None = None
    # Set once the owner proved the channel is theirs (code in the bio).
    owner_verified_at: datetime | None = None
    # Recording needs verification from this time (a grace period for
    # channels added before verification existed).
    verification_due_at: datetime | None = None
    # True when this channel can't be recorded until it is verified.
    verification_required: bool = False
    # Web only: what lets an unverified channel record on the website
    # ("web_attested" or "web_attested_legacy"); null otherwise. Legacy
    # channels should ask the user to tick the ownership box when edited.
    ownership_basis: str | None = None
    # Ops stopped this channel for this account after a report.
    blocked: bool = False
    # The bio code currently waiting to be checked and when it expires; null
    # once verified or when no unexpired code exists (never created by a read).
    pending_verification_code: str | None = None
    pending_verification_expires_at: datetime | None = None
    # The user's recordings of this channel that are not deleted (as listed by
    # GET /v1/recordings) and their total length.  Null where not computed.
    recording_count: int | None = None
    total_recorded_seconds: int | None = None
    # Length of the most recent finished (completed or stopped) recording of
    # this channel; null when there is none.
    last_live_duration_seconds: int | None = None


class ChannelVerificationResponse(StrictModel):
    watch_id: str
    verified: bool
    owner_verified_at: datetime | None
    verification_due_at: datetime | None
    verification_required: bool
    code: str | None
    expires_at: datetime | None
    checks_left: int
    result: Literal["verified", "code_not_found", "retry_later"] | None = None
    retry_after_seconds: int | None = None
    # Why a check answered retry_later (too_soon / still_checking /
    # tiktok_unavailable) and a sentence the app can show. Optional.
    reason: str | None = None
    message: str | None = None


class CreateWatchRequest(StrictModel):
    source: Source
    auto_record: bool
    notify_on_live: bool = True
    # "I own this channel or have the creator's permission to record it."
    # Optional on the app; required on the website once the web no longer
    # requires the bio code (SAVESTREAM_WEB_REQUIRE_OWNERSHIP=false).
    owner_attested: bool = False


class UpdateWatchRequest(StrictModel):
    auto_record: bool | None = None
    status: Literal["active", "paused", "disabled"] | None = None
    notify_on_live: bool | None = None
    # Website: tick the ownership box on an existing channel (stored as
    # consent evidence). Only true is accepted.
    owner_attested: Literal[True] | None = None

    @model_validator(mode="after")
    def at_least_one_field(self) -> "UpdateWatchRequest":
        if (
            self.auto_record is None
            and self.status is None
            and self.notify_on_live is None
            and self.owner_attested is None
        ):
            raise ValueError("At least one Watch field must be provided")
        return self


class WatchListResponse(StrictModel):
    items: list[WatchResponse]
    pagination: Pagination
