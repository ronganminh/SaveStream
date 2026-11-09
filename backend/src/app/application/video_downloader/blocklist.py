"""Takedown reports and the video downloader's blocklist.

A report blocks the video at once (before anyone reviews it) and opens an
admin complaint case, so ops review it in Admin > Safety like other reports
and can unblock it. The downloader container has no database access: the
active blocklist is mirrored into a Redis set that it reads, and it refuses
everything until that copy exists.
"""

from __future__ import annotations

import logging
import secrets
import uuid
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.downloader import links
from app.downloader.state import BLOCKLIST_KEY, BLOCKLIST_SYNCED_KEY
from app.infrastructure.db.admin_models import (
    AdminComplaintCase,
    AdminComplaintEvent,
    VideoDownloadBlock,
    VideoDownloadReport,
)
from app.infrastructure.rate_limit import RateLimiter

logger = logging.getLogger(__name__)

TurnstileVerifier = Callable[[str, str], Awaitable[bool]]
REPORT_RATE_LIMIT = 5
REPORT_RATE_WINDOW_SECONDS = 3600


class RedisSetClient(Protocol):
    def pipeline(self, transaction: bool = True) -> Any: ...
    async def sadd(self, name: str, *values: str) -> Any: ...
    async def srem(self, name: str, *values: str) -> Any: ...


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def new_reference() -> str:
    alphabet = "ABCDEFGHJKMNPQRSTVWXYZ23456789"
    return "DL-" + "".join(secrets.choice(alphabet) for _ in range(6))


def canonical_video(raw: str) -> links.VideoLink:
    """A full video link; short links cannot be checked without asking
    TikTok, which the API never does."""
    try:
        link = links.parse_link(raw)
    except links.InvalidLink as exc:
        raise ApplicationError("INVALID_LINK", str(exc), status_code=400) from exc
    if link.is_short:
        raise ApplicationError(
            "INVALID_LINK",
            "Please paste the full video link (tiktok.com/@name/video/...). "
            "Open the short link in a browser to get it.",
            status_code=400,
        )
    return link


@dataclass(slots=True)
class BlocklistService:
    session: AsyncSession
    redis: RedisSetClient | None = None

    async def _block(
        self,
        link: links.VideoLink,
        *,
        reason: str,
        source: str,
        report_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
    ) -> VideoDownloadBlock:
        assert link.video_id is not None
        row = await self.session.get(VideoDownloadBlock, link.video_id)
        if row is None:
            row = VideoDownloadBlock(
                video_id=link.video_id,
                video_url=link.url,
                reason=reason,
                source=source,
                report_id=report_id,
                blocked_by_user_id=actor_id,
                blocked_at=utcnow(),
            )
            self.session.add(row)
        elif row.unblocked_at is not None:
            row.reason = reason
            row.source = source
            row.report_id = report_id or row.report_id
            row.blocked_by_user_id = actor_id
            row.blocked_at = utcnow()
            row.unblocked_at = None
            row.unblocked_by_user_id = None
            row.unblock_reason = None
        await self.session.flush()
        return row

    async def submit_report(
        self,
        *,
        video_url: str,
        reporter_name: str,
        reporter_email: str,
        relationship: str,
        reason: str,
        details: str,
    ) -> VideoDownloadReport:
        link = canonical_video(video_url)
        assert link.video_id is not None
        case = AdminComplaintCase(
            kind="copyright" if reason == "copyright" else "abuse",
            complainant_name=reporter_name.strip(),
            complainant_email=reporter_email.strip().casefold(),
            channel_source_type="username",
            channel_source_value=(link.username or "").casefold() or None,
            summary=f"Video downloader takedown: {link.video_id}"[:240],
            body="\n\n".join(
                [
                    f"Video: {link.url}",
                    f"Relationship: {relationship}",
                    f"Reason: {reason}",
                    f"Details:\n{details.strip()}",
                    "The video was blocked in the downloader when this report arrived.",
                    "Good-faith statement: confirmed",
                ]
            ),
            status="new",
            created_by_user_id=None,
        )
        self.session.add(case)
        await self.session.flush()
        report = VideoDownloadReport(
            reference=new_reference(),
            video_id=link.video_id,
            video_url=link.url,
            reporter_name=reporter_name.strip(),
            reporter_email=reporter_email.strip().casefold(),
            relationship=relationship,
            reason=reason,
            details=details.strip(),
            complaint_id=case.id,
            created_at=utcnow(),
        )
        self.session.add(report)
        await self.session.flush()
        await self._block(
            link, reason=f"Report {report.reference}", source="report", report_id=report.id
        )
        self.session.add(
            AdminComplaintEvent(
                complaint_id=case.id,
                actor_user_id=None,
                action="created",
                note=f"Video downloader report {report.reference}; video blocked.",
                metadata_json={"source": "video_downloader_report", "video_id": link.video_id},
                created_at=utcnow(),
            )
        )
        await self.session.flush()
        return report

    async def block(
        self, *, video_url: str, reason: str, actor_id: uuid.UUID
    ) -> VideoDownloadBlock:
        return await self._block(
            canonical_video(video_url), reason=reason.strip(), source="manual", actor_id=actor_id
        )

    async def unblock(
        self, video_id: str, *, reason: str, actor_id: uuid.UUID
    ) -> VideoDownloadBlock:
        row = await self.session.get(VideoDownloadBlock, video_id)
        if row is None or row.unblocked_at is not None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "This video is not blocked", status_code=404
            )
        row.unblocked_at = utcnow()
        row.unblocked_by_user_id = actor_id
        row.unblock_reason = reason.strip()
        await self.session.flush()
        return row

    async def list_blocks(self, *, active_only: bool, limit: int = 200) -> list[VideoDownloadBlock]:
        statement = select(VideoDownloadBlock).order_by(VideoDownloadBlock.blocked_at.desc())
        if active_only:
            statement = statement.where(VideoDownloadBlock.unblocked_at.is_(None))
        return list((await self.session.scalars(statement.limit(limit))).all())

    async def list_reports(self, *, limit: int = 50) -> list[VideoDownloadReport]:
        statement = (
            select(VideoDownloadReport).order_by(VideoDownloadReport.created_at.desc()).limit(limit)
        )
        return list((await self.session.scalars(statement)).all())

    async def report_references(self, report_ids: set[uuid.UUID]) -> dict[uuid.UUID, str]:
        if not report_ids:
            return {}
        rows = await self.session.execute(
            select(VideoDownloadReport.id, VideoDownloadReport.reference).where(
                VideoDownloadReport.id.in_(report_ids)
            )
        )
        return {row[0]: row[1] for row in rows.all()}

    async def active_ids(self) -> set[str]:
        rows = await self.session.scalars(
            select(VideoDownloadBlock.video_id).where(VideoDownloadBlock.unblocked_at.is_(None))
        )
        return set(rows.all())


async def push_change(redis: RedisSetClient, *, video_id: str, blocked: bool) -> None:
    """Apply one block/unblock to the downloader's copy (after the commit)."""
    if blocked:
        await redis.sadd(BLOCKLIST_KEY, video_id)
    else:
        await redis.srem(BLOCKLIST_KEY, video_id)


async def sync_to_redis(session: AsyncSession, redis: RedisSetClient) -> int:
    """Replace the downloader's copy with the database and mark it synced."""
    ids = await BlocklistService(session).active_ids()
    temp = f"{BLOCKLIST_KEY}:sync:{secrets.token_hex(4)}"
    pipe = redis.pipeline(transaction=True)
    if ids:
        pipe.sadd(temp, *sorted(ids))
        pipe.rename(temp, BLOCKLIST_KEY)
    else:
        pipe.delete(BLOCKLIST_KEY)
    pipe.set(BLOCKLIST_SYNCED_KEY, utcnow().isoformat())
    await pipe.execute()
    return len(ids)


async def guard_report(
    rate_limiter: RateLimiter,
    *,
    client_ip: str,
    turnstile_secret: str,
    turnstile_token: str | None,
    turnstile: TurnstileVerifier,
) -> None:
    await rate_limiter.hit(
        scope="video_downloader_report",
        identifier=client_ip,
        limit=REPORT_RATE_LIMIT,
        window_seconds=REPORT_RATE_WINDOW_SECONDS,
    )
    if not turnstile_secret:
        return
    if not turnstile_token or not await turnstile(turnstile_token, client_ip):
        raise ApplicationError(
            "CAPTCHA_FAILED", "Please complete the verification and try again.", status_code=400
        )
