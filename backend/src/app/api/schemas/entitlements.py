from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class EntitlementLimitsResponse(StrictModel):
    max_watches: int
    max_concurrent_cloud_recordings: int
    cloud_retention_days: int


class LocalEntitlementResponse(StrictModel):
    enabled: bool
    unlimited: bool
    daily_minutes: int
    minutes_remaining: int
    resets_at: datetime
    rewards_used_today: int
    rewards_cap_per_day: int
    minutes_per_reward: int
    extensions_cap_per_recording: int
    max_concurrent_sessions: int
    second_slot_expires_at: datetime | None


class AdsEntitlementResponse(StrictModel):
    rewarded_available: bool
    rewards_left_today: int
    rewards_cap_per_day: int
    minutes_per_reward: int
    resets_at: datetime
    show_banners: bool


class EntitlementResponse(StrictModel):
    plan: Literal["free", "pro"]
    has_purchased: bool
    email_verified: bool = False
    # Auto-record may be switched on: purchased credit, or free trial credit
    # on a verified email (trial_recording).
    can_auto_record: bool = False
    trial_recording: bool = False
    cloud_minutes_available: int
    limits: EntitlementLimitsResponse
    watch_count: int
    local: LocalEntitlementResponse
    ads: AdsEntitlementResponse | None = None
    updated_at: datetime
