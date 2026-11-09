"""Provider 2: yt-dlp, an independent open-source TikTok extractor.

yt-dlp does not expose the creator's download setting, so its answers carry
``download_allowed=None``; the public tool only uses them when the page
provider has confirmed downloads are allowed for the same video.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any

from .base import MediaSource, ProviderError, VideoInfo, VideoUnavailable, cookie_header

_PRIVATE_HINTS = ("private", "login required", "log in", "sign in")
_REMOVED_HINTS = ("not available", "unavailable", "removed", "does not exist", "not found", "10204")


class YtDlpProvider:
    name = "ytdlp"

    def __init__(self, *, proxy_url: str | None = None) -> None:
        self.proxy_url = proxy_url or None

    async def resolve(self, url: str, *, video_id: str, timeout: float) -> VideoInfo:
        return await asyncio.to_thread(self._resolve, url, video_id, timeout)

    def _resolve(self, url: str, video_id: str, timeout: float) -> VideoInfo:
        import yt_dlp

        options: dict[str, Any] = {
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "skip_download": True,
            "noplaylist": True,
            "cachedir": False,
            "socket_timeout": timeout,
            "extractor_retries": 0,
            "logger": _QuietLogger(),
        }
        if self.proxy_url:
            options["proxy"] = self.proxy_url
        try:
            with yt_dlp.YoutubeDL(options) as ydl:
                info = ydl.extract_info(url, download=False)
                cookies = {
                    cookie.name: cookie.value or ""
                    for cookie in ydl.cookiejar
                    if cookie.domain.endswith("tiktok.com")
                }
        except yt_dlp.utils.DownloadError as exc:
            message = str(exc).lower()
            if any(hint in message for hint in _PRIVATE_HINTS):
                raise VideoUnavailable("private") from exc
            if any(hint in message for hint in _REMOVED_HINTS):
                raise VideoUnavailable("removed") from exc
            raise ProviderError("yt-dlp could not extract the video") from exc
        if not isinstance(info, dict):
            raise ProviderError("yt-dlp returned nothing")
        return parse_info(info, video_id=video_id, cookies=cookies, provider=self.name)


def parse_info(
    info: dict[str, Any], *, video_id: str, cookies: dict[str, str], provider: str
) -> VideoInfo:
    if str(info.get("id") or "") != video_id:
        raise ProviderError("yt-dlp returned a different video")
    cookie = cookie_header(cookies)
    videos: list[MediaSource] = []
    audio: MediaSource | None = None
    for fmt in info.get("formats") or []:
        media_url = fmt.get("url")
        if not isinstance(media_url, str) or not media_url.startswith("https://"):
            continue
        headers = {str(k): str(v) for k, v in (fmt.get("http_headers") or {}).items()}
        if cookie:
            headers["Cookie"] = cookie
        vcodec = str(fmt.get("vcodec") or "")
        acodec = str(fmt.get("acodec") or "")
        note = f"{fmt.get('format_id') or ''} {fmt.get('format_note') or ''}".lower()
        if vcodec == "none":
            if acodec and acodec != "none" and audio is None:
                audio = MediaSource(
                    url=media_url, headers=headers, extension=str(fmt.get("ext") or "m4a")
                )
            continue
        videos.append(
            MediaSource(
                url=media_url,
                headers=headers,
                width=_int(fmt.get("width")),
                height=_int(fmt.get("height")),
                codec=vcodec or None,
                size_bytes=_int(fmt.get("filesize") or fmt.get("filesize_approx")),
                extension=str(fmt.get("ext") or "mp4"),
                watermarked=fmt.get("format_id") == "download" or "watermark" in note,
            )
        )
    if not videos:
        raise ProviderError("yt-dlp found no video formats")
    thumbnail = info.get("thumbnail")
    timestamp = _int(info.get("timestamp"))
    return VideoInfo(
        video_id=video_id,
        username=str(info.get("uploader") or info.get("channel") or "").lstrip("@"),
        author_name=str(info.get("channel") or info.get("uploader") or ""),
        caption=str(info.get("description") or info.get("title") or ""),
        duration_seconds=_int(info.get("duration")),
        posted_at=datetime.fromtimestamp(timestamp, tz=timezone.utc) if timestamp else None,
        videos=tuple(videos),
        audio=audio,
        cover=MediaSource(url=thumbnail, headers=videos[0].headers, extension="jpg")
        if isinstance(thumbnail, str) and thumbnail.startswith("https://")
        else None,
        provider=provider,
        author_id=str(info.get("uploader_id") or "") or None,
    )


class _QuietLogger:
    def debug(self, msg: str) -> None:
        pass

    def info(self, msg: str) -> None:
        pass

    def warning(self, msg: str) -> None:
        pass

    def error(self, msg: str) -> None:
        pass


def _int(value: object) -> int | None:
    try:
        number = int(float(str(value)))
    except (TypeError, ValueError):
        return None
    return number if number > 0 else None
