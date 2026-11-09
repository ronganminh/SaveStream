"""Ask the providers in order and decide what may be served.

Public mode (anyone): only videos whose creator allows downloads, and only
TikTok's own downloadable file (the one its Save button gives, with TikTok's
watermark). The permission must be confirmed by a provider that can read it
(the page provider); if no provider can confirm it the answer is "unknown",
which is refused like "off".

Owner mode (a signed-in user downloading a video from their own verified
channel): the creator's setting does not apply, and the best stream is
offered as well as TikTok's download file.

Private or removed videos stop the chain at once; no provider is asked to get
around that.
"""

from __future__ import annotations

import asyncio
import logging
import time
from dataclasses import dataclass, field
from typing import Literal

from app.downloader.providers.base import (
    MediaSource,
    Provider,
    ProviderError,
    VideoInfo,
    VideoUnavailable,
)

logger = logging.getLogger(__name__)

Mode = Literal["public", "owner"]


class DownloadsDisabled(Exception):
    """The creator turned downloads off for this video (public mode)."""


class PermissionUnknown(Exception):
    """No provider could confirm the creator allows downloads (public mode)."""


class NoProviderAnswer(Exception):
    """Every provider failed or was skipped."""


@dataclass(slots=True)
class CircuitBreaker:
    """Skip a provider for `cooldown` seconds after `threshold` failures
    within `window` seconds; one trial request then decides."""

    threshold: int = 5
    window: float = 120.0
    cooldown: float = 300.0
    failures: list[float] = field(default_factory=list)
    open_until: float = 0.0

    def allow(self, now: float) -> bool:
        return now >= self.open_until

    def success(self) -> None:
        self.failures.clear()
        self.open_until = 0.0

    def failure(self, now: float) -> None:
        self.failures = [t for t in self.failures if now - t < self.window] + [now]
        if len(self.failures) >= self.threshold:
            self.open_until = now + self.cooldown
            self.failures.clear()


@dataclass(frozen=True, slots=True)
class Resolved:
    info: VideoInfo
    files: tuple[MediaSource, ...]


@dataclass(slots=True)
class ProviderChain:
    providers: list[Provider]
    timeouts: dict[str, float]
    breakers: dict[str, CircuitBreaker] = field(default_factory=dict)
    clock: object = time.monotonic

    def _breaker(self, name: str) -> CircuitBreaker:
        return self.breakers.setdefault(name, CircuitBreaker())

    async def resolve(self, url: str, *, video_id: str, mode: Mode) -> Resolved:
        permission: bool | None = None
        candidates: list[VideoInfo] = []
        for provider in self.providers:
            name = provider.name
            breaker = self._breaker(name)
            now = self.clock()  # type: ignore[operator]
            if not breaker.allow(now):
                logger.info("downloader provider=%s outcome=skipped_breaker", name)
                continue
            started = time.monotonic()
            try:
                info = await asyncio.wait_for(
                    provider.resolve(url, video_id=video_id, timeout=self.timeouts.get(name, 15.0)),
                    timeout=self.timeouts.get(name, 15.0) + 5.0,
                )
            except VideoUnavailable as exc:
                breaker.success()
                logger.info("downloader provider=%s outcome=%s", name, exc.reason)
                raise
            except (ProviderError, TimeoutError, asyncio.TimeoutError) as exc:
                breaker.failure(self.clock())  # type: ignore[operator]
                logger.info(
                    "downloader provider=%s outcome=failed reason=%s ms=%d",
                    name,
                    type(exc).__name__,
                    (time.monotonic() - started) * 1000,
                )
                continue
            except Exception:  # an upstream library bug must not break the chain
                breaker.failure(self.clock())  # type: ignore[operator]
                logger.exception("downloader provider=%s outcome=error", name)
                continue
            breaker.success()
            logger.info(
                "downloader provider=%s outcome=ok ms=%d",
                name,
                (time.monotonic() - started) * 1000,
            )
            if info.download_allowed is not None and permission is None:
                permission = info.download_allowed
            candidates.append(info)
            if mode == "public":
                if permission is False:
                    raise DownloadsDisabled()
                if permission is True:
                    for candidate in candidates:
                        if files := public_files(candidate):
                            return Resolved(info=_with_permission(candidate, True), files=files)
            else:
                if files := owner_files(info):
                    return Resolved(info=info, files=files)
        if mode == "public" and candidates:
            if permission is None:
                raise PermissionUnknown()
        raise NoProviderAnswer()


def public_files(info: VideoInfo) -> tuple[MediaSource, ...]:
    """TikTok's own downloadable (watermarked) file, nothing else."""
    marked = [source for source in info.videos if source.watermarked]
    return tuple(marked[:1])


def owner_files(info: VideoInfo) -> tuple[MediaSource, ...]:
    """For the creator: the best clean stream, plus TikTok's download file."""
    clean = sorted(
        (source for source in info.videos if not source.watermarked),
        key=lambda source: ((source.height or 0), (source.size_bytes or 0)),
        reverse=True,
    )
    marked = [source for source in info.videos if source.watermarked]
    return tuple(clean[:1] + marked[:1])


def _with_permission(info: VideoInfo, allowed: bool) -> VideoInfo:
    if info.download_allowed is allowed:
        return info
    from dataclasses import replace

    return replace(info, download_allowed=allowed)
