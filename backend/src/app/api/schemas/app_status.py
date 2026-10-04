from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class MinimumSupportedVersions(StrictModel):
    android: str
    ios: str


class MaintenanceStatus(StrictModel):
    active: bool
    eta: datetime | None


class AppStatusResponse(StrictModel):
    min_supported_version: MinimumSupportedVersions
    maintenance: MaintenanceStatus
