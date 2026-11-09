"""TikTok video links the downloader accepts, and safe short-link expansion.

Only links to a single video on TikTok's own hosts are accepted. Short links
(vm./vt./t.tiktok.com, www.tiktok.com/t/...) are expanded one redirect at a
time without following redirects automatically; every hop must stay on a
TikTok host and the last one must be a canonical video page. Credentials,
custom ports and anything else in the authority part are refused, so a link
can never point the server at another host (SSRF).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from urllib.parse import urljoin, urlsplit

import httpx

from app.downloader.providers.base import BROWSER_USER_AGENT

FULL_HOSTS = frozenset({"tiktok.com", "www.tiktok.com", "m.tiktok.com"})
SHORT_HOSTS = frozenset({"vm.tiktok.com", "vt.tiktok.com", "t.tiktok.com"})
_VIDEO_PATH = re.compile(r"^/@([A-Za-z0-9._-]{1,64})/video/(\d{8,25})/?$")
_SHORT_PATH = re.compile(r"^/(?:t/)?([A-Za-z0-9]{4,24})/?$")
MAX_LINK_LENGTH = 2048
MAX_REDIRECTS = 5
_REDIRECTS = {301, 302, 303, 307, 308}


class InvalidLink(ValueError):
    """Not a link to a single public TikTok video."""


@dataclass(frozen=True, slots=True)
class VideoLink:
    """A canonical video link, or a short link still to expand."""

    url: str
    video_id: str | None = None
    username: str | None = None

    @property
    def is_short(self) -> bool:
        return self.video_id is None


def _parts(raw: str) -> tuple[str, str]:
    text = (raw or "").strip()
    if not text or len(text) > MAX_LINK_LENGTH:
        raise InvalidLink("Paste a link to a TikTok video")
    if "://" not in text:
        text = "https://" + text
    try:
        parts = urlsplit(text)
        port = parts.port
    except ValueError as exc:
        raise InvalidLink("Paste a link to a TikTok video") from exc
    host = (parts.hostname or "").lower().rstrip(".")
    if parts.scheme not in {"http", "https"} or host not in FULL_HOSTS | SHORT_HOSTS:
        raise InvalidLink("Only TikTok video links are supported")
    if parts.username or parts.password or port not in {None, 80, 443}:
        raise InvalidLink("Only TikTok video links are supported")
    return host, parts.path or "/"


def parse_link(raw: str) -> VideoLink:
    host, path = _parts(raw)
    if host in FULL_HOSTS:
        if match := _VIDEO_PATH.match(path):
            return canonical(match.group(1), match.group(2))
        if path.startswith("/t/") and _SHORT_PATH.match(path):
            return VideoLink(url=f"https://www.tiktok.com{path.rstrip('/')}/")
    elif _SHORT_PATH.match(path):
        return VideoLink(url=f"https://{host}{path.rstrip('/')}/")
    raise InvalidLink("Paste a link to a single TikTok video")


def canonical(username: str, video_id: str) -> VideoLink:
    return VideoLink(
        url=f"https://www.tiktok.com/@{username}/video/{video_id}",
        video_id=video_id,
        username=username,
    )


async def expand(link: VideoLink, client: httpx.AsyncClient) -> VideoLink:
    """Follow a short link hop by hop until it names a video."""
    if not link.is_short:
        return link
    current = link.url
    for _ in range(MAX_REDIRECTS):
        try:
            response = await client.get(
                current,
                follow_redirects=False,
                headers={"User-Agent": BROWSER_USER_AGENT, "Range": "bytes=0-0"},
            )
        except httpx.HTTPError as exc:
            raise InvalidLink("We couldn't open this TikTok link") from exc
        await response.aclose()
        location = response.headers.get("location", "")
        if response.status_code not in _REDIRECTS or not location:
            break
        current = urljoin(current, location)
        host, path = _parts(current)
        if host in FULL_HOSTS and (match := _VIDEO_PATH.match(path)):
            return canonical(match.group(1), match.group(2))
    raise InvalidLink("This link does not lead to a TikTok video")
