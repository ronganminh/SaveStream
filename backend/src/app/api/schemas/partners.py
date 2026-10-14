from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class PartnerApplicationRequest(BaseModel):
    """Body of /partners/apply. ``photo`` is an optional PNG/JPG data URL (≤ 5 MB)."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=200)
    email: str = Field(min_length=3, max_length=320, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    tiktok_handle: str = Field(min_length=2, max_length=64)
    other_channel_url: str | None = Field(default=None, max_length=2048)
    niche: str = Field(min_length=1, max_length=64)
    story: str = Field(min_length=20, max_length=600)
    photo: str | None = Field(default=None, max_length=7_000_000)
    consent_owns_account: bool
    consent_display: bool
    turnstile_token: str | None = Field(default=None, max_length=4_096)
    # Honeypot: hidden input; a filled value gets a normal reply, nothing is stored.
    website: str | None = Field(default=None, max_length=2_048)


class PartnerApplicationReceipt(BaseModel):
    reference: str


class PartnerStoryResponse(BaseModel):
    """A published creator story; only fields the creator consented to show."""

    id: str
    name: str
    tiktok_handle: str
    niche: str
    story: str
    has_photo: bool
    published_at: datetime | None


class PartnerStoryListResponse(BaseModel):
    items: list[PartnerStoryResponse]


PartnerStatus = Literal["pending", "approved", "rejected", "published", "withdrawn"]


class AdminPartnerApplicationResponse(BaseModel):
    id: str
    reference: str
    name: str
    email: str
    tiktok_handle: str
    other_channel_url: str | None
    niche: str
    story: str
    has_photo: bool
    status: PartnerStatus
    consent_texts: list[str]
    terms_version: str
    privacy_version: str
    consent_ip: str | None
    consent_user_agent: str | None
    consent_withdrawn_at: datetime | None
    published_at: datetime | None
    created_at: datetime
    updated_at: datetime


class AdminPartnerApplicationListResponse(BaseModel):
    items: list[AdminPartnerApplicationResponse]
    counts: dict[str, int]


class AdminPartnerActionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    action: Literal["approve", "reject", "publish", "unpublish"]
    reason: str = Field(min_length=10, max_length=500)
