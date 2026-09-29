from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass
from typing import Any, Awaitable, Protocol, cast

from redis.asyncio import Redis

from app.domain.common.errors import ApplicationError


class RateLimiter(Protocol):
    async def hit(
        self,
        *,
        scope: str,
        identifier: str,
        limit: int,
        window_seconds: int,
    ) -> None: ...


class RedisRateLimiter:
    _SCRIPT = """
local current = redis.call('INCR', KEYS[1])
if current == 1 then
  redis.call('EXPIRE', KEYS[1], ARGV[1])
end
local ttl = redis.call('TTL', KEYS[1])
return {current, ttl}
"""

    def __init__(self, redis: Redis, prefix: str = "savestream:ratelimit") -> None:
        self.redis = redis
        self.prefix = prefix

    @staticmethod
    def _digest(identifier: str) -> str:
        return hashlib.sha256(identifier.encode("utf-8")).hexdigest()

    async def hit(
        self,
        *,
        scope: str,
        identifier: str,
        limit: int,
        window_seconds: int,
    ) -> None:
        key = f"{self.prefix}:{scope}:{self._digest(identifier)}"
        result = await cast(Awaitable[Any], self.redis.eval(self._SCRIPT, 1, key, str(window_seconds)))
        current = int(result[0])
        ttl = max(int(result[1]), 0)
        if current > limit:
            raise ApplicationError(
                "RATE_LIMITED",
                "Too many requests",
                status_code=429,
                retryable=True,
                details={"retry_after_seconds": ttl},
            )


@dataclass(slots=True)
class _MemoryBucket:
    count: int
    reset_at: float


class InMemoryRateLimiter:
    """Test/local helper with the same contract as the Redis limiter."""

    def __init__(self) -> None:
        self._buckets: dict[str, _MemoryBucket] = {}

    async def hit(
        self,
        *,
        scope: str,
        identifier: str,
        limit: int,
        window_seconds: int,
    ) -> None:
        now = time.monotonic()
        key = f"{scope}:{identifier}"
        bucket = self._buckets.get(key)
        if bucket is None or bucket.reset_at <= now:
            bucket = _MemoryBucket(count=0, reset_at=now + window_seconds)
            self._buckets[key] = bucket
        bucket.count += 1
        if bucket.count > limit:
            raise ApplicationError(
                "RATE_LIMITED",
                "Too many requests",
                status_code=429,
                retryable=True,
                details={"retry_after_seconds": max(int(bucket.reset_at - now), 0)},
            )
