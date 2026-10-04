from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", from_attributes=True)


class AdminSupportReportResponse(StrictModel):
    id: str
    user_id: str
    user_email: str
    recording_id: str | None
    description: str
    diagnostic_log: dict[str, Any]
    app_version: str | None
    platform: str | None
    status: Literal["new", "reviewing", "resolved", "closed"]
    assigned_to_user_id: str | None
    resolved_at: datetime | None
    expires_at: datetime
    created_at: datetime
    updated_at: datetime


class AdminSupportReportListResponse(StrictModel):
    items: list[AdminSupportReportResponse]
    next_cursor: str | None
    has_more: bool


class AdminSupportReportUpdateRequest(StrictModel):
    status: Literal["new", "reviewing", "resolved", "closed"]
    assigned_to_user_id: str | None = None
    reason: str = Field(min_length=3, max_length=500)


class AdminDailyMetricResponse(StrictModel):
    day: date
    new_users: int = Field(ge=0)
    active_users_daily: int = Field(ge=0)
    active_users_weekly: int = Field(ge=0)
    active_users_monthly: int = Field(ge=0)
    free_users: int = Field(ge=0)
    pro_users: int = Field(ge=0)
    free_to_pro_weekly: int = Field(ge=0)
    revenue_web_usd_minor: int = Field(ge=0)
    revenue_app_store_usd_minor: int = Field(ge=0)
    revenue_google_play_usd_minor: int = Field(ge=0)
    estimated_store_fee_app_store_usd_minor: int = Field(ge=0)
    estimated_store_fee_google_play_usd_minor: int = Field(ge=0)
    recording_running: int = Field(ge=0)
    recording_waiting: int = Field(ge=0)
    recording_errors_24h: int = Field(ge=0)
    recording_total_24h: int = Field(ge=0)
    cloud_minutes_used: int = Field(ge=0)
    recording_status_counts: dict[str, int]
    recording_capacity_limit: int = Field(ge=1)
    stuck_orders: int = Field(ge=0)
    open_complaints: int = Field(ge=0)
    computed_at: datetime


class AdminOverviewResponse(StrictModel):
    latest: AdminDailyMetricResponse | None
    series: list[AdminDailyMetricResponse]
    month_revenue_web_usd_minor: int = Field(ge=0)
    month_revenue_app_store_usd_minor: int = Field(ge=0)
    month_revenue_google_play_usd_minor: int = Field(ge=0)
    month_estimated_store_fee_usd_minor: int = Field(ge=0)
