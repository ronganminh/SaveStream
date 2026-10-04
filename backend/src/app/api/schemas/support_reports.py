from __future__ import annotations

import json
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

        def walk(item: Any) -> None:
            if isinstance(item, dict):
                for key, child in item.items():
                    if str(key).casefold() in forbidden:
                        raise ValueError(
                            "Diagnostics must not contain video or media payloads"
                        )
                    walk(child)
            elif isinstance(item, list):
                for child in item:
                    walk(child)

        walk(value)
        if len(json.dumps(value, separators=(",", ":")).encode("utf-8")) > 100_000:
            raise ValueError("Diagnostics payload is too large")
        return value


class SupportReportResponse(StrictModel):
    report_id: str
