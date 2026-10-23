"""Keep a copy of each channel's TikTok avatar in object storage.

TikTok serves avatars from signed CDN URLs that expire after a few days, so
clients showing the raw URL eventually get a broken image. A periodic task
copies the image to object storage under a stable key and records a public
API URL for it (`creator_avatar_cached_url`), which web and mobile receive as
`creator.avatar_url`. A channel's copy is made when it is added and refreshed
every `creator_avatar_refresh_hours`; when the raw URL has expired, the TikTok
profile is looked up again first. The channel lookup shown while adding a
channel gets its own copy too, so clients never load TikTok's CDN directly.
Everything here is best-effort: clients fall back to initials.
"""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import logging
import uuid
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from typing import Protocol

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import Source
from app.application.watches.service import CreatorMetadataLookup
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.storage.media_urls import media_avatar_url, media_delivery_enabled
from app.settings import AppSettings

logger = logging.getLogger(__name__)

AVATAR_KEY_PREFIX = "creator-avatars/"
AVATAR_PUBLIC_PATH = "/v1/public/creator-avatars/"
# A failed copy is retried after this long rather than a full refresh period.
FAILED_RETRY_AFTER = timedelta(hours=1)


class AvatarStorage(Protocol):
    def upload_bytes(
        self,
        data: bytes,
        storage_key: str,
        *,
        content_type: str,
        cache_control: str | None = None,
    ) -> None: ...

    def remove(self, storage_key: str) -> None: ...


AvatarFetcher = Callable[[str], "tuple[bytes, str] | None"]


def avatar_key(avatar_id: str) -> str:
    return f"{AVATAR_KEY_PREFIX}{avatar_id}"


def avatar_public_url(settings: AppSettings, avatar_id: str) -> str:
    """Public URL of a cached avatar: the media Worker's edge-cached `/a/<id>`
    when it is configured, else the API route (both stay valid)."""
    if media_delivery_enabled(settings):
        return media_avatar_url(settings, avatar_id)
    return f"{settings.public_api_base_url.rstrip('/')}{AVATAR_PUBLIC_PATH}{avatar_id}"


def lookup_avatar_id(settings: AppSettings, username: str) -> str:
    """Id of the copy shown while a channel is being added: one per handle,
    overwritten on each lookup, and not guessable from the handle (keyed)."""
    message = f"lookup:tiktok:{username.strip().lower()}".encode()
    return hmac.new(settings.jwt_secret.encode(), message, hashlib.sha256).hexdigest()[:32]


async def cache_lookup_avatar(
    settings: AppSettings,
    storage: AvatarStorage,
    fetch: AvatarFetcher,
    *,
    username: str,
    source_url: str | None,
    timeout_seconds: float = 5.0,
) -> str | None:
    """Copy a looked-up channel's avatar and return our URL for it; None when
    there is none or it can't be copied in time (clients show initials)."""
    if not source_url or not settings.public_api_base_url:
        return None
    try:
        image = await asyncio.wait_for(asyncio.to_thread(fetch, source_url), timeout_seconds)
    except Exception:
        logger.info("Lookup avatar download failed", exc_info=True)
        return None
    if image is None:
        return None
    data, content_type = image
    avatar_id = lookup_avatar_id(settings, username)
    try:
        await asyncio.to_thread(
            storage.upload_bytes,
            data,
            avatar_key(avatar_id),
            content_type=content_type,
            cache_control="public, max-age=3600",
        )
    except Exception:
        logger.warning("Lookup avatar upload failed", exc_info=True)
        return None
    return avatar_public_url(settings, avatar_id)


class CreatorAvatarCache:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        storage: AvatarStorage,
        fetch: AvatarFetcher,
        lookup: CreatorMetadataLookup | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.storage = storage
        self.fetch = fetch
        self.lookup = lookup

    async def remove_deleted(self) -> int:
        """Delete the stored copy of avatars whose channel was deleted."""
        watches = list(
            (
                await self.session.scalars(
                    select(Watch)
                    .where(
                        Watch.deleted_at.is_not(None),
                        Watch.creator_avatar_key.is_not(None),
                    )
                    .limit(self.settings.creator_avatar_batch_size)
                )
            ).all()
        )
        removed = 0
        for watch in watches:
            if await remove_avatar_copy(self.storage, watch):
                removed += 1
        await self.session.commit()
        return removed

    async def refresh_due(self, *, now: datetime | None = None) -> int:
        """Copy or refresh a batch of avatars that are missing or stale."""
        if not self.settings.public_api_base_url:
            return 0
        current = now or datetime.now(timezone.utc)
        await self._retarget_cached_urls()
        stale_before = current - timedelta(hours=self.settings.creator_avatar_refresh_hours)
        watches = list(
            (
                await self.session.scalars(
                    select(Watch)
                    .where(
                        Watch.deleted_at.is_(None),
                        or_(
                            Watch.creator_avatar_url.is_not(None),
                            Watch.creator_avatar_key.is_not(None),
                        ),
                        or_(
                            Watch.creator_avatar_refreshed_at.is_(None),
                            Watch.creator_avatar_refreshed_at < stale_before,
                        ),
                    )
                    .order_by(Watch.creator_avatar_refreshed_at.asc().nulls_first())
                    .limit(self.settings.creator_avatar_batch_size)
                )
            ).all()
        )
        stored = 0
        for watch in watches:
            if await self.refresh_watch(watch, now=current):
                stored += 1
            await self.session.commit()
        return stored

    async def _retarget_cached_urls(self) -> None:
        """Point already-cached avatars at the current public URL (e.g. the
        media Worker once it is enabled) without downloading them again."""
        rows = (
            await self.session.scalars(
                select(Watch).where(
                    Watch.creator_avatar_key.is_not(None),
                    Watch.creator_avatar_cached_url.is_not(None),
                )
            )
        ).all()
        changed = False
        for watch in rows:
            assert watch.creator_avatar_key is not None
            url = avatar_public_url(
                self.settings, watch.creator_avatar_key.removeprefix(AVATAR_KEY_PREFIX)
            )
            if watch.creator_avatar_cached_url != url:
                watch.creator_avatar_cached_url = url
                changed = True
        if changed:
            await self.session.commit()

    async def refresh_watch(self, watch: Watch, *, now: datetime) -> bool:
        image = await self._download(watch.creator_avatar_url)
        if image is None and self.lookup is not None:
            # The signed CDN URL has probably expired; ask TikTok for a new one.
            try:
                metadata = await self.lookup.lookup(
                    Source.model_validate(
                        {"type": watch.source_type, "value": watch.source_value}
                    )
                )
            except Exception:
                logger.info("Creator avatar profile lookup failed", exc_info=True)
                metadata = None
            if metadata is not None and metadata.avatar_url:
                watch.creator_avatar_url = metadata.avatar_url
                image = await self._download(metadata.avatar_url)
        if image is None:
            # Keep any previous copy; retry sooner than a full refresh period.
            refresh_period = timedelta(hours=self.settings.creator_avatar_refresh_hours)
            watch.creator_avatar_refreshed_at = now - refresh_period + FAILED_RETRY_AFTER
            return False

        data, content_type = image
        avatar_id = (
            watch.creator_avatar_key.removeprefix(AVATAR_KEY_PREFIX)
            if watch.creator_avatar_key
            else uuid.uuid4().hex
        )
        try:
            await asyncio.to_thread(
                self.storage.upload_bytes,
                data,
                avatar_key(avatar_id),
                content_type=content_type,
                cache_control="public, max-age=86400",
            )
        except Exception:
            logger.warning("Creator avatar upload failed", exc_info=True)
            watch.creator_avatar_refreshed_at = (
                now
                - timedelta(hours=self.settings.creator_avatar_refresh_hours)
                + FAILED_RETRY_AFTER
            )
            return False
        watch.creator_avatar_key = avatar_key(avatar_id)
        watch.creator_avatar_cached_url = avatar_public_url(self.settings, avatar_id)
        watch.creator_avatar_refreshed_at = now
        return True

    async def _download(self, url: str | None) -> tuple[bytes, str] | None:
        if not url:
            return None
        try:
            return await asyncio.to_thread(self.fetch, url)
        except Exception:
            logger.info("Creator avatar download failed", exc_info=True)
            return None


async def remove_avatar_copy(storage: AvatarStorage, watch: Watch) -> bool:
    """Remove a watch's stored avatar and forget it; the caller commits.

    Keeps the fields when storage fails so the periodic cleanup retries.
    """
    if not watch.creator_avatar_key:
        return False
    try:
        await asyncio.to_thread(storage.remove, watch.creator_avatar_key)
    except Exception:
        logger.warning("Creator avatar removal failed", exc_info=True)
        return False
    watch.creator_avatar_key = None
    watch.creator_avatar_cached_url = None
    watch.creator_avatar_refreshed_at = None
    return True


async def recording_avatar_urls(
    session: AsyncSession,
    recordings: list[Recording],
) -> dict[uuid.UUID, str]:
    """Avatar for each recording, taken from its owner's Watch of the same creator."""
    from app.api.serializers.watches import creator_avatar_url

    wanted = {
        (item.user_id, item.resolved_username.lower())
        for item in recordings
        if item.resolved_username
    }
    if not wanted:
        return {}
    watches = (
        await session.scalars(
            select(Watch).where(
                Watch.user_id.in_({user_id for user_id, _ in wanted}),
                Watch.resolved_username.is_not(None),
            )
        )
    ).all()
    by_creator: dict[tuple[uuid.UUID, str], str] = {}
    for watch in sorted(watches, key=lambda w: w.deleted_at is not None):
        url = creator_avatar_url(watch)
        key = (watch.user_id, (watch.resolved_username or "").lower())
        if url and key in wanted:
            by_creator.setdefault(key, url)
    return {
        item.id: by_creator[(item.user_id, item.resolved_username.lower())]
        for item in recordings
        if item.resolved_username
        and (item.user_id, item.resolved_username.lower()) in by_creator
    }
