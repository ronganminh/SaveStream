from __future__ import annotations

import re
from urllib.parse import urljoin, urlsplit, urlunsplit

import requests

_ALLOWED_HOSTS = {
    "tiktok.com",
    "www.tiktok.com",
    "m.tiktok.com",
    "vm.tiktok.com",
    "vt.tiktok.com",
    "t.tiktok.com",
}
_CANONICAL_PATH = re.compile(r"^/@[A-Za-z0-9._-]+/video/[0-9]+/?$")
_MAX_REDIRECTS = 5


class InvalidTikTokUrl(ValueError):
    pass


def _validated_parts(value: str):
    candidate = value.strip()
    if not candidate or len(candidate) > 2048:
        raise InvalidTikTokUrl("A valid TikTok video URL is required")
    if "://" not in candidate:
        candidate = "https://" + candidate
    try:
        parsed = urlsplit(candidate)
        port = parsed.port
    except ValueError as exc:
        raise InvalidTikTokUrl("Invalid TikTok URL") from exc
    host = (parsed.hostname or "").lower().rstrip(".")
    if parsed.scheme not in {"http", "https"} or host not in _ALLOWED_HOSTS:
        raise InvalidTikTokUrl("Only TikTok video links are supported")
    if parsed.username or parsed.password or port not in {None, 80, 443}:
        raise InvalidTikTokUrl("TikTok URL contains unsupported authority information")
    return parsed, host


def normalize_tiktok_url(value: str, *, session: requests.Session | None = None) -> str:
    """Resolve TikTok short links without following redirects to arbitrary hosts."""
    parsed, host = _validated_parts(value)
    current = urlunsplit(("https", parsed.netloc, parsed.path, parsed.query, ""))
    if _CANONICAL_PATH.fullmatch(parsed.path):
        return current

    client = session or requests.Session()
    owns_session = session is None
    try:
        for _ in range(_MAX_REDIRECTS):
            parts, current_host = _validated_parts(current)
            if _CANONICAL_PATH.fullmatch(parts.path):
                return urlunsplit(("https", parts.netloc, parts.path, parts.query, ""))
            if current_host not in {"vm.tiktok.com", "vt.tiktok.com", "t.tiktok.com", "www.tiktok.com", "m.tiktok.com", "tiktok.com"}:
                raise InvalidTikTokUrl("TikTok redirect target is not supported")
            try:
                response = client.get(
                    current,
                    allow_redirects=False,
                    stream=True,
                    timeout=(5, 10),
                    headers={"User-Agent": "SaveStream/1.0", "Range": "bytes=0-0"},
                )
            except requests.RequestException as exc:
                raise InvalidTikTokUrl("Could not resolve this TikTok link") from exc
            try:
                if response.is_redirect or response.is_permanent_redirect:
                    location = response.headers.get("Location")
                    if not location:
                        raise InvalidTikTokUrl("TikTok returned an invalid redirect")
                    next_url = urljoin(current, location)
                    _validated_parts(next_url)
                    current = next_url
                    continue
                if response.status_code < 400 and _CANONICAL_PATH.fullmatch(parts.path):
                    return current
                raise InvalidTikTokUrl("This link does not resolve to a public TikTok video")
            finally:
                response.close()
        raise InvalidTikTokUrl("Too many redirects while resolving TikTok link")
    finally:
        if owns_session:
            client.close()
