"""Short-lived state in Redis: media tokens, per-IP limits, the blocklist.

Nothing here is a file: a media token holds the TikTok media URL and the
headers its CDN needs for at most `token_ttl_seconds` (10 minutes), so the
visitor can start the download. Limits are keyed by a hash of the IP and
expire with their window.
"""

from __future__ import annotations

import hashlib
import json
import secrets
from dataclasses import asdict, dataclass, field
from typing import Any, Literal, Protocol

PREFIX = "savestream:video_downloader"
BLOCKLIST_KEY = f"{PREFIX}:blocked_videos"
# Set by the API after it has copied the whole blocklist into Redis. Until it
# exists the public tool refuses to serve anything (fail closed).
BLOCKLIST_SYNCED_KEY = f"{PREFIX}:blocked_videos:synced"


class RedisLike(Protocol):
    async def get(self, name: str) -> Any: ...
    async def set(self, name: str, value: Any, ex: int | None = None) -> Any: ...
    async def incr(self, name: str) -> int: ...
    async def expire(self, name: str, time: int) -> Any: ...
    async def ttl(self, name: str) -> int: ...
    async def sismember(self, name: str, value: str) -> Any: ...
    async def exists(self, *names: str) -> int: ...


def ip_hash(ip: str) -> str:
    return hashlib.sha256(f"video-downloader:{ip}".encode()).hexdigest()[:32]


@dataclass(slots=True)
class MediaEntry:
    url: str
    headers: dict[str, str]
    filename: str
    video_id: str
    kind: Literal["video", "cover"]
    mode: Literal["public", "owner"]
    ip_hash: str
    size_bytes: int | None = None
    user_id: str | None = None
    usernames: list[str] = field(default_factory=list)


class MediaStore:
    def __init__(self, redis: RedisLike, ttl_seconds: int) -> None:
        self.redis = redis
        self.ttl = ttl_seconds

    async def put(self, entry: MediaEntry) -> str:
        token = secrets.token_urlsafe(24)
        await self.redis.set(f"{PREFIX}:media:{token}", json.dumps(asdict(entry)), ex=self.ttl)
        return token

    async def get(self, token: str) -> MediaEntry | None:
        if not token or len(token) > 64:
            return None
        raw = await self.redis.get(f"{PREFIX}:media:{token}")
        if not raw:
            return None
        try:
            return MediaEntry(**json.loads(raw))
        except (TypeError, ValueError):
            return None


@dataclass(frozen=True, slots=True)
class ResolveQuota:
    count: int
    retry_after_seconds: int


async def count_resolve(redis: RedisLike, ip: str, window_seconds: int) -> ResolveQuota:
    key = f"{PREFIX}:resolves:{ip_hash(ip)}"
    count = int(await redis.incr(key))
    if count == 1:
        await redis.expire(key, window_seconds)
    ttl = int(await redis.ttl(key))
    return ResolveQuota(count=count, retry_after_seconds=max(ttl, 0))


async def blocklist_ready(redis: RedisLike) -> bool:
    return bool(await redis.exists(BLOCKLIST_SYNCED_KEY))


async def is_blocked(redis: RedisLike, video_id: str) -> bool:
    return bool(await redis.sismember(BLOCKLIST_KEY, video_id))
