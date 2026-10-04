from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.api.schemas.recordings import Pagination


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminPackageResponse(StrictModel):
    id: str
    code: str
    name: str
    credits: int = Field(ge=1)
    amount_minor: int = Field(ge=0)
    currency: Literal["USD"] = "USD"
    active: bool
    display_order: int
    app_store_product_id: str | None
    google_play_product_id: str | None
    web_variant_id: str | None
    order_count: int = Field(ge=0)
    created_at: datetime
    updated_at: datetime


class AdminPackageCreateRequest(StrictModel):
    code: str = Field(min_length=2, max_length=80)
    name: str = Field(min_length=1, max_length=160)
    credits: int = Field(ge=1)
    amount_minor: int = Field(ge=0)
    display_order: int = 0
    app_store_product_id: str | None = Field(default=None, max_length=160)
    google_play_product_id: str | None = Field(default=None, max_length=160)
    web_variant_id: str | None = Field(default=None, max_length=160)
    reason: str = Field(min_length=3, max_length=500)


class AdminPackageUpdateRequest(StrictModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    credits: int | None = Field(default=None, ge=1)
    amount_minor: int | None = Field(default=None, ge=0)
    display_order: int | None = None
    active: bool | None = None
    app_store_product_id: str | None = Field(default=None, max_length=160)
    google_play_product_id: str | None = Field(default=None, max_length=160)
    web_variant_id: str | None = Field(default=None, max_length=160)
    clear_app_store_product_id: bool = False
    clear_google_play_product_id: bool = False
    clear_web_variant_id: bool = False
    reason: str = Field(min_length=3, max_length=500)


class AdminPackageListResponse(StrictModel):
    items: list[AdminPackageResponse]


class AdminPromotionResponse(StrictModel):
    id: str
    code: str
    credits: int = Field(ge=1)
    expires_at: datetime | None
    max_redemptions: int | None = Field(default=None, ge=1)
    redemption_count: int = Field(ge=0)
    active: bool
    counts_as_purchase: bool
    created_at: datetime
    updated_at: datetime


class AdminPromotionCreateRequest(StrictModel):
    code: str = Field(min_length=3, max_length=64)
    credits: int = Field(ge=1)
    expires_at: datetime | None = None
    max_redemptions: int | None = Field(default=None, ge=1)
    counts_as_purchase: bool = False
    reason: str = Field(min_length=3, max_length=500)


class AdminPromotionUpdateRequest(StrictModel):
    credits: int | None = Field(default=None, ge=1)
    expires_at: datetime | None = None
    clear_expires_at: bool = False
    max_redemptions: int | None = Field(default=None, ge=1)
    clear_max_redemptions: bool = False
    active: bool | None = None
    counts_as_purchase: bool | None = None
    reason: str = Field(min_length=3, max_length=500)


class AdminPromotionListResponse(StrictModel):
    items: list[AdminPromotionResponse]


class AdminPromotionRedemptionResponse(StrictModel):
    id: str
    user_id: str
    user_email: str
    ledger_entry_id: str | None
    created_at: datetime


class AdminPromotionRedemptionListResponse(StrictModel):
    items: list[AdminPromotionRedemptionResponse]
    pagination: Pagination


class AdminBulkGrantFilters(StrictModel):
    query: str | None = Field(default=None, max_length=160)
    plan: Literal["free", "pro"] | None = None
    account_status: Literal["active", "locked", "pending_deletion", "deleted"] | None = None
    email_verified: bool | None = None
    created_from: datetime | None = None
    created_to: datetime | None = None
    purchase_provider: str | None = Field(default=None, max_length=80)


class AdminBulkGrantPreviewRequest(StrictModel):
    credits: int = Field(ge=1)
    filters: AdminBulkGrantFilters = Field(default_factory=AdminBulkGrantFilters)


class AdminBulkGrantPreviewResponse(StrictModel):
    audience_count: int = Field(ge=0)
    credits_per_user: int = Field(ge=1)
    total_credits: int = Field(ge=0)


class AdminBulkGrantCreateRequest(AdminBulkGrantPreviewRequest):
    counts_as_purchase: bool = False
    reason: str = Field(min_length=3, max_length=500)


class AdminBulkGrantResponse(StrictModel):
    id: str
    credits: int = Field(ge=1)
    counts_as_purchase: bool
    reason: str
    filters: dict[str, object]
    status: Literal["queued", "running", "completed", "failed"]
    audience_count: int = Field(ge=0)
    total_credits: int = Field(ge=0)
    delivered_count: int = Field(ge=0)
    failed_count: int = Field(ge=0)
    error: str | None
    created_at: datetime
    started_at: datetime | None
    completed_at: datetime | None


class AdminBulkGrantDeliveryResponse(StrictModel):
    id: str
    user_id: str
    user_email: str
    ledger_entry_id: str | None
    status: Literal["queued", "delivered", "failed"]
    error: str | None
    created_at: datetime
    updated_at: datetime


class AdminBulkGrantDeliveryListResponse(StrictModel):
    items: list[AdminBulkGrantDeliveryResponse]
    pagination: Pagination
