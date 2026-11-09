"""Owner downloads: a signed-in web user downloads videos from their own
verified channels, even when the channel has downloads turned off.

Ownership is checked here, against the database, for every resolve and every
file download: the grant the downloader needs lives 60 seconds.
"""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.downloader import grants, links
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.rate_limit import RateLimiter
from app.settings import AppSettings

GRANTS_PER_HOUR = 120


async def verified_channels(session: AsyncSession, user_id: object) -> list[Watch]:
    """The user's channels verified with the bio code and not blocked."""
    rows = await session.scalars(
        select(Watch)
        .where(
            Watch.user_id == user_id,
            Watch.deleted_at.is_(None),
            Watch.owner_verified_at.is_not(None),
            Watch.blocked_at.is_(None),
        )
        .order_by(Watch.created_at)
    )
    return list(rows.all())


def channel_username(watch: Watch) -> str | None:
    name = watch.resolved_username or (
        watch.source_value if watch.source_type == "username" else None
    )
    return grants.normalize(name) if name else None


def require_web(principal: AuthPrincipal) -> None:
    if principal.is_mobile:
        raise ApplicationError(
            "WEB_ONLY",
            "Downloading your videos is available on the SaveStream website.",
            status_code=403,
        )


async def issue_grant(
    session: AsyncSession,
    settings: AppSettings,
    rate_limiter: RateLimiter,
    principal: AuthPrincipal,
    raw_url: str,
) -> str:
    require_web(principal)
    if not settings.video_downloader_enabled or not settings.video_downloader_grant_secret:
        raise ApplicationError(
            "DOWNLOADER_DISABLED",
            "The video downloader is not available right now.",
            status_code=503,
        )
    await rate_limiter.hit(
        scope="video_downloader_grant",
        identifier=str(principal.user_id),
        limit=GRANTS_PER_HOUR,
        window_seconds=3600,
    )
    channels = await verified_channels(session, principal.user_id)
    if not channels:
        raise ApplicationError(
            "NO_VERIFIED_CHANNEL",
            "Verify one of your channels with the bio code to download its videos.",
            status_code=403,
        )
    usernames = [name for watch in channels if (name := channel_username(watch))]
    tiktok_ids = [
        watch.owner_verified_tiktok_id for watch in channels if watch.owner_verified_tiktok_id
    ]
    try:
        link = links.parse_link(raw_url)
    except links.InvalidLink as exc:
        raise ApplicationError("INVALID_LINK", str(exc), status_code=400) from exc
    # A full link names the channel: refuse others here. Short links are
    # checked by the downloader against the video's real author.
    if not link.is_short and grants.normalize(link.username or "") not in set(usernames):
        raise ApplicationError(
            "NOT_YOUR_CHANNEL",
            "This video isn't from one of your verified channels.",
            status_code=403,
        )
    return grants.issue(
        settings.video_downloader_grant_secret,
        user_id=str(principal.user_id),
        usernames=usernames,
        tiktok_ids=tiktok_ids,
    )
