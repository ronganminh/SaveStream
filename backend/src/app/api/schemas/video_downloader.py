from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class VideoDownloadReportRequest(BaseModel):
    """Body of the downloader's report / copyright removal form."""

    model_config = ConfigDict(extra="forbid")

    video_url: str = Field(min_length=1, max_length=2048)
    reporter_name: str = Field(min_length=1, max_length=200)
    reporter_email: str = Field(min_length=3, max_length=320, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    relationship: Literal["creator", "rights_holder", "agent", "other"]
    reason: Literal["copyright", "privacy", "other"]
    details: str = Field(default="", max_length=5_000)
    good_faith: Literal[True]
    turnstile_token: str | None = Field(default=None, max_length=4_096)
    # Honeypot: a hidden input people never see; bots fill it in.
    website: str | None = Field(default=None, max_length=2_048)


class VideoDownloadReportResponse(BaseModel):
    reference: str


class AdminVideoBlockRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    video_url: str = Field(min_length=1, max_length=2048)
    reason: str = Field(min_length=3, max_length=500)


class AdminVideoUnblockRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: str = Field(min_length=3, max_length=500)


class AdminVideoBlockResponse(BaseModel):
    video_id: str
    video_url: str
    reason: str
    source: str
    report_reference: str | None
    blocked_at: datetime
    unblocked_at: datetime | None
    unblock_reason: str | None


class AdminVideoBlockListResponse(BaseModel):
    items: list[AdminVideoBlockResponse]


class AdminVideoReportResponse(BaseModel):
    reference: str
    video_id: str
    video_url: str
    reporter_name: str
    reporter_email: str
    relationship: str
    reason: str
    details: str
    created_at: datetime
    blocked: bool


class AdminVideoReportListResponse(BaseModel):
    items: list[AdminVideoReportResponse]
