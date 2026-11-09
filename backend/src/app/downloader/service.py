"""The public downloader: resolve a link, then stream the allowed file."""

from __future__ import annotations

import asyncio
import logging
import re
from collections.abc import AsyncIterator, Awaitable, Callable
from dataclasses import dataclass
from typing import Any

import httpx

from app.domain.common.errors import ApplicationError
from app.downloader import grants, links
from app.downloader.chain import (
    DownloadsDisabled,
    NoProviderAnswer,
    PermissionUnknown,
    Mode,
    ProviderChain,
    Resolved,
)
from app.downloader.config import DownloaderSettings
from app.downloader.media import MediaRefused, MediaTooLarge, OpenMedia, open_media
from app.downloader.providers.base import VideoUnavailable
from app.downloader.state import (
    MediaEntry,
    MediaStore,
    RedisLike,
    blocklist_ready,
    count_owner,
    count_resolve,
    ip_hash,
    is_blocked,
)

logger = logging.getLogger(__name__)

TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
COVER_MAX_BYTES = 5 * 1024 * 1024
FILE_PATH = "/v1/public/video-downloader/file/"
OWNER_FILE_PATH = "/v1/public/video-downloader/owner/file/"
OWNER_LIMIT_PER_HOUR = 60
COVER_PATH = "/v1/public/video-downloader/cover/"

TurnstileVerifier = Callable[[str, str], Awaitable[bool]]


def _error(code: str, message: str, status: int, **details: Any) -> ApplicationError:
    return ApplicationError(
        code,
        message,
        status_code=status,
        retryable=status in {429, 503},
        details=details,
    )


def disabled_error() -> ApplicationError:
    return _error("DOWNLOADER_DISABLED", "The video downloader is not available right now.", 503)


def unavailable_error() -> ApplicationError:
    return _error(
        "DOWNLOADER_UNAVAILABLE",
        "We couldn't reach TikTok just now. Please try again in a few minutes.",
        503,
    )


async def verify_turnstile(secret: str, token: str, remote_ip: str) -> bool:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                TURNSTILE_VERIFY_URL,
                data={"secret": secret, "response": token, "remoteip": remote_ip},
            )
        return bool(response.json().get("success"))
    except (httpx.HTTPError, ValueError):
        return False


def safe_filename(username: str, video_id: str, extension: str) -> str:
    handle = re.sub(r"[^A-Za-z0-9._-]", "", username)[:40] or "video"
    ext = re.sub(r"[^a-z0-9]", "", extension.lower())[:5] or "mp4"
    return f"tiktok-{handle}-{video_id}.{ext}"


@dataclass(slots=True)
class DownloaderService:
    settings: DownloaderSettings
    redis: RedisLike
    chain: ProviderChain
    http: httpx.AsyncClient
    turnstile: TurnstileVerifier
    streams: asyncio.Semaphore

    @property
    def store(self) -> MediaStore:
        return MediaStore(self.redis, self.settings.token_ttl_seconds)

    def require_enabled(self) -> None:
        if not self.settings.enabled:
            raise disabled_error()

    async def _guard_quota(self, ip: str, turnstile_token: str | None) -> bool:
        """Count this resolve; returns whether the next one needs Turnstile."""
        settings = self.settings
        quota = await count_resolve(self.redis, ip, settings.resolve_window_seconds)
        limit = settings.resolve_limit
        if not settings.turnstile_secret_key:
            # Without Turnstile there is no second tier: stop at the free tier.
            limit = min(limit, settings.turnstile_after)
        if quota.count > limit:
            raise _error(
                "RATE_LIMITED",
                "Too many downloads from your network. Try again later.",
                429,
                retry_after_seconds=quota.retry_after_seconds,
            )
        if quota.count > settings.turnstile_after:
            if not turnstile_token or not await self.turnstile(turnstile_token, ip):
                raise _error(
                    "CAPTCHA_REQUIRED",
                    "Please complete the check to continue.",
                    400,
                    turnstile_required=True,
                )
        return bool(settings.turnstile_secret_key) and quota.count >= settings.turnstile_after

    async def resolve(
        self, raw_url: str, *, ip: str, turnstile_token: str | None
    ) -> dict[str, Any]:
        self.require_enabled()
        if not await blocklist_ready(self.redis):
            logger.warning("downloader refused: blocklist not synced yet")
            raise unavailable_error()
        try:
            link = links.parse_link(raw_url)
        except links.InvalidLink as exc:
            raise _error("INVALID_LINK", str(exc), 400) from exc
        turnstile_next = await self._guard_quota(ip, turnstile_token)
        try:
            link = await links.expand(link, self.http)
        except links.InvalidLink as exc:
            raise _error("INVALID_LINK", str(exc), 400) from exc
        assert link.video_id is not None
        await self._refuse_blocked(link.video_id)
        resolved = await self._resolve(link)
        await self._refuse_blocked(resolved.info.video_id)
        return await self._result(resolved, ip=ip, turnstile_next=turnstile_next)

    async def _refuse_blocked(self, video_id: str) -> None:
        if await is_blocked(self.redis, video_id):
            raise _error(
                "VIDEO_BLOCKED",
                "This video was removed from the downloader after a request from its rights holder.",
                451,
            )

    async def _resolve(self, link: links.VideoLink, mode: Mode = "public") -> Resolved:
        assert link.video_id is not None
        try:
            resolved = await self.chain.resolve(link.url, video_id=link.video_id, mode=mode)
        except VideoUnavailable as exc:
            raise _error(
                "VIDEO_UNAVAILABLE",
                "This video is private, removed or not a video.",
                404,
                reason=exc.reason,
            ) from exc
        except DownloadsDisabled as exc:
            raise _error(
                "DOWNLOADS_DISABLED",
                "The creator turned off downloads for this video.",
                403,
            ) from exc
        except (PermissionUnknown, NoProviderAnswer) as exc:
            logger.info("downloader resolve failed: %s", type(exc).__name__)
            raise unavailable_error() from exc
        info = resolved.info
        if info.duration_seconds and info.duration_seconds > self.settings.max_duration_seconds:
            raise _error(
                "VIDEO_TOO_LONG",
                "This video is longer than 10 minutes, the limit for this tool.",
                413,
                max_duration_seconds=self.settings.max_duration_seconds,
            )
        if all((f.size_bytes or 0) > self.settings.max_bytes for f in resolved.files):
            raise _error("VIDEO_TOO_LARGE", "This video is larger than 300 MB.", 413)
        return resolved

    async def _result(
        self,
        resolved: Resolved,
        *,
        ip: str,
        turnstile_next: bool,
        owner: grants.Grant | None = None,
    ) -> dict[str, Any]:
        info = resolved.info
        hashed = ip_hash(ip)
        mode: Mode = "owner" if owner else "public"
        extra: dict[str, Any] = {}
        if owner:
            extra = {
                "user_id": owner.user_id,
                "author_username": info.username,
                "author_id": info.author_id,
            }
        files = []
        for source in resolved.files:
            if (source.size_bytes or 0) > self.settings.max_bytes:
                continue
            token = await self.store.put(
                MediaEntry(
                    url=source.url,
                    headers=source.headers,
                    filename=safe_filename(info.username, info.video_id, source.extension),
                    video_id=info.video_id,
                    kind="video",
                    mode=mode,
                    ip_hash=hashed,
                    size_bytes=source.size_bytes,
                    **extra,
                )
            )
            label = "MP4"
            if owner:
                label = "MP4 (TikTok download)" if source.watermarked else "Original"
            files.append(
                {
                    "kind": "video",
                    "format": "mp4",
                    "label": label,
                    "watermarked": source.watermarked,
                    "width": source.width,
                    "height": source.height,
                    "size_bytes": source.size_bytes,
                    "download_url": f"{OWNER_FILE_PATH if owner else FILE_PATH}{token}",
                }
            )
        cover_url = None
        if info.cover is not None:
            token = await self.store.put(
                MediaEntry(
                    url=info.cover.url,
                    headers=info.cover.headers,
                    filename="cover.jpg",
                    video_id=info.video_id,
                    kind="cover",
                    mode=mode,
                    ip_hash=hashed,
                    **extra,
                )
            )
            cover_url = f"{COVER_PATH}{token}"
        logger.info(
            "downloader resolved mode=%s video_id=%s provider=%s files=%d",
            mode,
            info.video_id,
            info.provider,
            len(files),
        )
        return {
            "video": {
                "id": info.video_id,
                "username": info.username,
                "author_name": info.author_name,
                "caption": info.caption[:500],
                "duration_seconds": info.duration_seconds,
                "posted_at": info.posted_at.isoformat() if info.posted_at else None,
                "cover_url": cover_url,
                "downloads_allowed_by_creator": bool(info.download_allowed),
            },
            "files": files,
            "expires_in_seconds": self.settings.token_ttl_seconds,
            "turnstile_required_next": turnstile_next,
        }

    def _grant(self, token: str | None) -> grants.Grant:
        try:
            return grants.verify(self.settings.grant_secret, token)
        except grants.InvalidGrant as exc:
            raise _error(
                "GRANT_INVALID",
                "Your session for this download has expired. Please try again.",
                403,
            ) from exc

    async def owner_resolve(self, raw_url: str, *, grant_token: str, ip: str) -> dict[str, Any]:
        """A video from one of the signed-in user's verified channels: the
        creator's download setting does not apply to their own videos."""
        self.require_enabled()
        grant = self._grant(grant_token)
        quota = await count_owner(self.redis, grant.user_id, 3600)
        if quota.count > OWNER_LIMIT_PER_HOUR:
            raise _error(
                "RATE_LIMITED",
                "Too many downloads. Try again later.",
                429,
                retry_after_seconds=quota.retry_after_seconds,
            )
        try:
            link = links.parse_link(raw_url)
            if not link.is_short and not grant.owns(username=link.username, tiktok_id=None):
                raise _not_yours()
            link = await links.expand(link, self.http)
        except links.InvalidLink as exc:
            raise _error("INVALID_LINK", str(exc), 400) from exc
        resolved = await self._resolve(link, mode="owner")
        info = resolved.info
        if not grant.owns(username=info.username, tiktok_id=info.author_id):
            raise _not_yours()
        return await self._result(resolved, ip=ip, turnstile_next=False, owner=grant)

    async def open_file(
        self, token: str, *, ip: str, kind: str, grant_token: str | None = None
    ) -> tuple[MediaEntry, OpenMedia, Callable[[], None]]:
        """Check the token and open the media; the caller must call the
        returned release function when the stream ends. Owner files need a
        fresh grant: the API re-checks ownership for every download."""
        self.require_enabled()
        entry = await self.store.get(token)
        if entry is None or entry.kind != kind or entry.ip_hash != ip_hash(ip):
            raise _error(
                "LINK_EXPIRED",
                "This download link has expired. Paste the TikTok link again.",
                410,
            )
        if entry.mode == "owner":
            if kind == "video" or grant_token is not None:
                grant = self._grant(grant_token)
                if grant.user_id != entry.user_id or not grant.owns(
                    username=entry.author_username, tiktok_id=entry.author_id
                ):
                    raise _not_yours()
        elif grant_token is not None:
            raise _error(
                "LINK_EXPIRED",
                "This download link has expired. Paste the TikTok link again.",
                410,
            )
        if entry.mode == "public":
            if not await blocklist_ready(self.redis):
                raise unavailable_error()
            await self._refuse_blocked(entry.video_id)
        if kind == "video":
            if self.streams.locked():
                raise _error(
                    "DOWNLOADER_BUSY",
                    "The downloader is busy. Please try again in a minute.",
                    503,
                )
            await self.streams.acquire()
            release = self.streams.release
            max_bytes = self.settings.max_bytes
            accept: tuple[str, ...] = ("video/", "application/octet-stream", "binary/octet-stream")
        else:
            release = _noop
            max_bytes = COVER_MAX_BYTES
            accept = ("image/",)
        try:
            media = await open_media(
                self.http, entry.url, entry.headers, max_bytes=max_bytes, accept=accept
            )
        except MediaTooLarge as exc:
            release()
            raise _error("VIDEO_TOO_LARGE", "This video is larger than 300 MB.", 413) from exc
        except (MediaRefused, httpx.HTTPError) as exc:
            release()
            logger.info("downloader media refused: %s", type(exc).__name__)
            raise unavailable_error() from exc
        return entry, media, release


async def stream_and_release(
    media: OpenMedia, max_bytes: int, release: Callable[[], None]
) -> AsyncIterator[bytes]:
    try:
        async for chunk in media.chunks(max_bytes):
            yield chunk
    except MediaTooLarge:
        logger.info("downloader stream cut at the byte cap")
    finally:
        release()


def _not_yours() -> ApplicationError:
    return _error(
        "NOT_YOUR_CHANNEL", "This video isn't from one of your verified channels.", 403
    )


def _noop() -> None:
    return None
