from __future__ import annotations

from urllib.parse import urlparse

import httpx

# Avatar copies are served from our own API origin, so only plain raster
# images are accepted (never SVG/HTML) and only from TikTok's image CDNs.
ALLOWED_AVATAR_TYPES = frozenset(
    {"image/jpeg", "image/png", "image/webp", "image/gif", "image/avif"}
)
_ALLOWED_HOST_SUFFIXES = (
    ".tiktokcdn.com",
    ".tiktokcdn-us.com",
    ".tiktokcdn-eu.com",
    ".ibyteimg.com",
    ".byteimg.com",
    ".muscdn.com",
)
MAX_AVATAR_BYTES = 2 * 1024 * 1024


def avatar_url_allowed(url: str) -> bool:
    parsed = urlparse(url)
    host = (parsed.hostname or "").lower()
    return parsed.scheme == "https" and host.endswith(_ALLOWED_HOST_SUFFIXES)


def download_avatar(url: str, *, timeout_seconds: float = 10.0) -> tuple[bytes, str] | None:
    """Fetch a TikTok avatar image; None when it is unavailable or not an image."""
    if not avatar_url_allowed(url):
        return None
    try:
        with httpx.Client(timeout=timeout_seconds, follow_redirects=False) as client:
            with client.stream("GET", url, headers={"Accept": "image/*"}) as response:
                if response.status_code != 200:
                    return None
                content_type = response.headers.get("content-type", "").split(";")[0].strip()
                if content_type.lower() not in ALLOWED_AVATAR_TYPES:
                    return None
                chunks: list[bytes] = []
                size = 0
                for chunk in response.iter_bytes():
                    size += len(chunk)
                    if size > MAX_AVATAR_BYTES:
                        return None
                    chunks.append(chunk)
    except httpx.HTTPError:
        return None
    data = b"".join(chunks)
    return (data, content_type.lower()) if data else None
