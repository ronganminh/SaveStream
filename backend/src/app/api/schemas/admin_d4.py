from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AdminRuntimeSettingResponse(StrictModel):
    key: str
    kind: Literal["bool", "int", "version", "enum", "datetime"]
    description: str
    value: Any
    default_value: Any
    source: Literal["database", "environment"]
    minimum: int | None
    maximum: int | None
    choices: list[str]
    nullable: bool
    updated_by_user_id: str | None
    updated_at: datetime | None


class AdminRuntimeSettingListResponse(StrictModel):
    items: list[AdminRuntimeSettingResponse]


class AdminRuntimeSettingUpdateRequest(StrictModel):
    value: Any
    reason: str = Field(min_length=3, max_length=500)


class AdminRuntimeSettingResetRequest(StrictModel):
    reason: str = Field(min_length=3, max_length=500)
