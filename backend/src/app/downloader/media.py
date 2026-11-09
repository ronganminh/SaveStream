"""Streaming TikTok media to the visitor without storing it.

Only https URLs on TikTok-owned media hosts are fetched, every redirect is
checked against the same list, and the byte cap is enforced while streaming,
so a provider answer can never make the server fetch something else or keep
a file.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from dataclasses import dataclass
from urllib.parse import urljoin, urlsplit

import httpx

MEDIA_HOST_SUFFIXES = (
    ".tiktok.com",
    ".tiktokcdn.com",
    ".tiktokcdn-us.com",
    ".tiktokcdn-eu.com",
    ".tiktokv.com",
    ".tiktokv.us",
    ".tiktokv.eu",
    ".byteoversea.com",
    ".ibytedtos.com",
    ".ibyteimg.com",
    ".muscdn.com",
)
_PAGE_HOSTS = {"tiktok.com", "www.tiktok.com", "m.tiktok.com"}
_FORWARDED_HEADERS = {"user-agent", "referer", "cookie", "accept", "accept-language", "origin"}
MAX_MEDIA_REDIRECTS = 3
CHUNK = 64 * 1024


class MediaRefused(Exception):
    """The media URL or the response is not something we will pass on."""


class MediaTooLarge(MediaRefused):
    pass


def is_allowed_media_url(url: str) -> bool:
    try:
        parts = urlsplit(url)
        port = parts.port
    except ValueError:
        return False
    host = (parts.hostname or "").lower().rstrip(".")
    return (
        parts.scheme == "https"
        and not parts.username
        and not parts.password
        and port in {None, 443}
        and host not in _PAGE_HOSTS
        and any(host.endswith(suffix) for suffix in MEDIA_HOST_SUFFIXES)
    )


def _request_headers(headers: dict[str, str]) -> dict[str, str]:
    return {k: v for k, v in headers.items() if k.lower() in _FORWARDED_HEADERS}


@dataclass(slots=True)
class OpenMedia:
    response: httpx.Response
    content_type: str
    size: int | None

    async def chunks(self, max_bytes: int) -> AsyncIterator[bytes]:
        sent = 0
        try:
            async for chunk in self.response.aiter_bytes(CHUNK):
                sent += len(chunk)
                if sent > max_bytes:
                    raise MediaTooLarge("file is larger than the limit")
                yield chunk
        finally:
            await self.response.aclose()


async def open_media(
    client: httpx.AsyncClient,
    url: str,
    headers: dict[str, str],
    *,
    max_bytes: int,
    accept: tuple[str, ...] = ("video/", "application/octet-stream", "binary/octet-stream"),
) -> OpenMedia:
    """Open a media URL, following at most a few checked redirects."""
    current = url
    for _ in range(MAX_MEDIA_REDIRECTS + 1):
        if not is_allowed_media_url(current):
            raise MediaRefused("media host is not allowed")
        request = client.build_request("GET", current, headers=_request_headers(headers))
        response = await client.send(request, stream=True, follow_redirects=False)
        if response.status_code in {301, 302, 303, 307, 308}:
            location = response.headers.get("location", "")
            await response.aclose()
            current = urljoin(current, location)
            continue
        if response.status_code != 200:
            await response.aclose()
            raise MediaRefused(f"media answered HTTP {response.status_code}")
        content_type = response.headers.get("content-type", "").split(";", 1)[0].strip().lower()
        if not content_type.startswith(accept):
            await response.aclose()
            raise MediaRefused("media is not the expected type")
        size = None
        if (length := response.headers.get("content-length", "")).isdigit():
            size = int(length)
            if size > max_bytes:
                await response.aclose()
                raise MediaTooLarge("file is larger than the limit")
        return OpenMedia(response=response, content_type=content_type, size=size)
    raise MediaRefused("too many media redirects")
