"""Provider 2: SaveStream's own reader of the public video page.

TikTok embeds the page's data as JSON (`__UNIVERSAL_DATA_FOR_REHYDRATION__`);
the video's item has its play streams, TikTok's own download file, the music
track and the cover. No dependency beyond httpx, so it can be fixed the same
day TikTok changes its page.
"""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from typing import Any

import httpx

from .base import (
    BROWSER_USER_AGENT,
    MediaSource,
    ProviderError,
    VideoInfo,
    VideoUnavailable,
    cookie_header,
)

_DATA = re.compile(
    r'<script[^>]+id="__UNIVERSAL_DATA_FOR_REHYDRATION__"[^>]*>(.*?)</script>', re.S
)
# webapp.video-detail statusCode values.
_REMOVED = {10204, 10221}
_PRIVATE = {10216, 10222}


class PageProvider:
    name = "page"

    def __init__(
        self,
        *,
        proxy_url: str | None = None,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.proxy_url = proxy_url or None
        self.transport = transport

    async def resolve(self, url: str, *, video_id: str, timeout: float) -> VideoInfo:
        headers = {"User-Agent": BROWSER_USER_AGENT, "Accept-Language": "en-US,en;q=0.9"}
        try:
            async with httpx.AsyncClient(
                proxy=self.proxy_url,
                transport=self.transport,
                timeout=timeout,
                headers=headers,
                follow_redirects=False,
            ) as client:
                response = await client.get(url)
        except httpx.HTTPError as exc:
            raise ProviderError(f"page request failed: {type(exc).__name__}") from exc
        if response.status_code == 404:
            raise VideoUnavailable("removed")
        if response.status_code != 200:
            raise ProviderError(f"page answered HTTP {response.status_code}")
        match = _DATA.search(response.text)
        if match is None:
            raise ProviderError("page has no rehydration data")
        try:
            scope = json.loads(match.group(1))["__DEFAULT_SCOPE__"]
        except (ValueError, KeyError) as exc:
            raise ProviderError("rehydration data is not readable") from exc
        detail = scope.get("webapp.video-detail")
        if not isinstance(detail, dict):
            raise ProviderError("page has no video detail")
        status = int(detail.get("statusCode") or 0)
        if status in _REMOVED:
            raise VideoUnavailable("removed")
        if status in _PRIVATE:
            raise VideoUnavailable("private")
        if status != 0:
            raise ProviderError(f"video detail status {status}")
        item = (detail.get("itemInfo") or {}).get("itemStruct")
        if not isinstance(item, dict):
            raise ProviderError("video detail has no item")
        media_headers = {
            "User-Agent": BROWSER_USER_AGENT,
            "Referer": "https://www.tiktok.com/",
        }
        cookies = cookie_header(dict(response.cookies.items()))
        if cookies:
            media_headers["Cookie"] = cookies
        return parse_item(item, video_id=video_id, headers=media_headers, provider=self.name)


def parse_item(
    item: dict[str, Any], *, video_id: str, headers: dict[str, str], provider: str
) -> VideoInfo:
    """VideoInfo from a TikTok itemStruct (shared by the page provider and tests)."""
    author = item.get("author") or {}
    if item.get("secret") or item.get("privateItem") or item.get("forFriend"):
        raise VideoUnavailable("private")
    if author.get("privateAccount") or author.get("secret"):
        raise VideoUnavailable("private")
    if "imagePost" in item:
        raise VideoUnavailable("not_video")
    video = item.get("video")
    if not isinstance(video, dict):
        raise VideoUnavailable("not_video")
    if str(item.get("id") or video_id) != video_id:
        raise ProviderError("page shows a different video")

    sources: list[MediaSource] = []
    bitrate_info = video.get("bitrateInfo") or []
    if isinstance(bitrate_info, dict):
        bitrate_info = [bitrate_info]
    for entry in bitrate_info:
        play = (entry or {}).get("PlayAddr") or {}
        urls = [u for u in play.get("UrlList") or [] if isinstance(u, str)]
        if not urls:
            continue
        sources.append(
            MediaSource(
                url=urls[0],
                headers=headers,
                width=_int(play.get("Width")),
                height=_int(play.get("Height")),
                codec=str(entry.get("CodecType") or "") or None,
                size_bytes=_int(play.get("DataSize")),
            )
        )
    if not sources and isinstance(video.get("playAddr"), str) and video["playAddr"]:
        sources.append(
            MediaSource(
                url=video["playAddr"],
                headers=headers,
                width=_int(video.get("width")),
                height=_int(video.get("height")),
                codec=str(video.get("codecType") or "") or None,
            )
        )
    if isinstance(video.get("downloadAddr"), str) and video["downloadAddr"]:
        sources.append(
            MediaSource(
                url=video["downloadAddr"],
                headers=headers,
                width=_int(video.get("width")),
                height=_int(video.get("height")),
                watermarked=True,
            )
        )
    if not sources:
        raise ProviderError("item has no video streams")

    music = item.get("music") or {}
    audio = None
    if isinstance(music.get("playUrl"), str) and music["playUrl"]:
        audio = MediaSource(url=music["playUrl"], headers=headers, extension="mp3")
    cover_url = next(
        (video.get(key) for key in ("cover", "originCover", "dynamicCover") if video.get(key)),
        None,
    )
    created = _int(item.get("createTime"))
    setting = author.get("downloadSetting")
    download_allowed: bool | None
    if isinstance(setting, int) and not isinstance(setting, bool):
        download_allowed = setting == 0
    else:
        download_allowed = None
    return VideoInfo(
        video_id=video_id,
        username=str(author.get("uniqueId") or ""),
        author_name=str(author.get("nickname") or author.get("uniqueId") or ""),
        caption=str(item.get("desc") or ""),
        duration_seconds=_int(video.get("duration")),
        posted_at=datetime.fromtimestamp(created, tz=timezone.utc) if created else None,
        videos=tuple(sources),
        audio=audio,
        cover=MediaSource(url=cover_url, headers=headers, extension="jpg") if cover_url else None,
        provider=provider,
        download_allowed=download_allowed,
        author_id=str(author.get("id") or "") or None,
    )


def _int(value: object) -> int | None:
    try:
        number = int(str(value))
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None
