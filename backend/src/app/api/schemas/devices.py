from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class UpsertDeviceRequest(StrictModel):
    platform: Literal["android", "ios"]
    push_token: str | None = Field(max_length=4096)
    device_name: str = Field(min_length=1, max_length=160)
    app_version: str = Field(min_length=1, max_length=64)
    locale: str = Field(min_length=2, max_length=16)
