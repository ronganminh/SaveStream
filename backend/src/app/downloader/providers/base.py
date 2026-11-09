"""The interface every extraction provider implements."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal, Protocol

BROWSER_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)


@dataclass(frozen=True, slots=True)
class MediaSource:
    """One fetchable file, with the headers (cookies, referer) its CDN needs."""

    url: str
    headers: dict[str, str] = field(default_factory=dict)
    width: int | None = None
    height: int | None = None
    codec: str | None = None
    size_bytes: int | None = None
    extension: str = "mp4"
    # TikTok's own "save video" file; it carries TikTok's watermark.
    watermarked: bool = False


@dataclass(frozen=True, slots=True)
class VideoInfo:
    video_id: str
    username: str
    author_name: str
    caption: str
    duration_seconds: int | None
    posted_at: datetime | None
    videos: tuple[MediaSource, ...]
    audio: MediaSource | None
    cover: MediaSource | None
    provider: str = ""
    # The creator's download setting: True when TikTok says anyone may save
    # the video, False when the creator turned downloads off, None when this
    # provider cannot tell. The public tool only serves True.
    download_allowed: bool | None = None
    author_id: str | None = None


UnavailableReason = Literal["private", "removed", "not_video"]


class VideoUnavailable(Exception):
    """TikTok says the video cannot be seen (private, removed, or not a
    video). Final: the chain does not ask the next provider."""

    def __init__(self, reason: UnavailableReason, message: str = "") -> None:
        super().__init__(message or reason)
        self.reason = reason


class ProviderError(Exception):
    """This provider could not answer; the chain tries the next one."""


class Provider(Protocol):
    name: str

    async def resolve(self, url: str, *, video_id: str, timeout: float) -> VideoInfo: ...


def cookie_header(cookies: dict[str, str]) -> str:
    return "; ".join(f"{name}={value}" for name, value in cookies.items() if name)
