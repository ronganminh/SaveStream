from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class CreateVideoDownloadRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    url: str = Field(min_length=8, max_length=2048)
    format: Literal["mp4", "mp3"] = "mp4"


class CreateVideoDownloadResponse(BaseModel):
    job_id: str
    status: Literal["queued"]


class VideoDownloadStatusResponse(BaseModel):
    job_id: str
    status: Literal["queued", "processing", "completed", "failed"]
    title: str | None = None
    format: Literal["mp4", "mp3"] | None = None
    provider: str | None = None
    download_url: HttpUrl | None = None
    expires_in_seconds: int | None = None
    error: str | None = None
