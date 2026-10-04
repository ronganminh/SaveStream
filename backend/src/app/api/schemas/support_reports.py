from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, field_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class SupportReportCreateRequest(StrictModel):
    message: str = Field(min_length=3, max_length=20_000)
    recording_id: str | None = None
    diagnostics: dict[str, Any] = Field(default_factory=dict)

    @field_validator("diagnostics")
    @classmethod
    def reject_video_payloads(cls, value: dict[str, Any]) -> dict[str, Any]:
        forbidden = {"video", "video_bytes", "file", "file_bytes", "media", "blob"}
        keys = {str(key).casefold() for key in value}
        if keys & forbidden:
            raise ValueError("Diagnostics must not contain video or media payloads")
        return value


class SupportReportResponse(StrictModel):
    report_id: str
