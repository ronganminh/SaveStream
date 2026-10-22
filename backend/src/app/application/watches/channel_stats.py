"""Per-channel numbers shown with a Watch: recordings, recorded time, the
last finished LIVE and the pending bio code.

Recordings carry no ``watch_id``; like ``active_recording_for`` they belong to
a Watch by creator handle (case-insensitive) or TikTok room id.  Everything is
read with a fixed number of aggregate queries per request, never per Watch,
and nothing is written (in particular no verification code is created).
"""

from __future__ import annotations

import uuid
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import ChannelVerification, Watch
from app.settings import AppSettings

# A LIVE counts as finished once its recording ended with media: completed,
# or stopped by the user/credit cap.  Failed and missed jobs have no reliable
# length.
FINISHED_RECORDING_STATUSES = (
    RecordingStatus.COMPLETED.value,
    RecordingStatus.STOPPED.value,
)


@dataclass(frozen=True, slots=True)
class WatchExtras:
    recording_count: int = 0
    total_recorded_seconds: int = 0
    last_live_duration_seconds: int | None = None
    pending_verification_code: str | None = None
    pending_verification_expires_at: datetime | None = None


@dataclass(frozen=True, slots=True)
class _Group:
    username: str | None
    room_id: str | None
    count: int
    seconds: int


@dataclass(frozen=True, slots=True)
class _Last:
    username: str | None
    room_id: str | None
    ended_at: datetime
    seconds: int


def _aware(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _matches(watch: Watch, username: str | None, room_id: str | None) -> bool:
    handle = (watch.resolved_username or "").lstrip("@").casefold() or (
        watch.source_value.lstrip("@").casefold() if watch.source_type == "username" else ""
    )
    if handle and username is not None and username.lstrip("@").casefold() == handle:
        return True
    return bool(watch.resolved_room_id) and room_id == watch.resolved_room_id


async def watch_extras(
    session: AsyncSession,
    settings: AppSettings,
    *,
    user_id: uuid.UUID,
    watches: Sequence[Watch],
    now: datetime | None = None,
) -> dict[uuid.UUID, WatchExtras]:
    if not watches:
        return {}
    now = now or datetime.now(timezone.utc)
    # A job queued by username has no resolved_username until it resolves.
    username_key = func.lower(
        func.coalesce(
            Recording.resolved_username,
            case((Recording.source_type == "username", Recording.source_value)),
        )
    )
    # Recordings the user can see, as in GET /v1/recordings.
    visible = (Recording.user_id == user_id, Recording.deleted_at.is_(None))

    groups = [
        _Group(username, room_id, int(count or 0), int(seconds or 0))
        for username, room_id, count, seconds in (
            await session.execute(
                select(
                    username_key,
                    Recording.room_id,
                    func.count(Recording.id),
                    func.coalesce(func.sum(Recording.duration_seconds), 0),
                )
                .where(*visible)
                .group_by(username_key, Recording.room_id)
            )
        ).all()
    ]

    # Latest finished recording per (handle, room): one row per group.
    ranked = (
        select(
            username_key.label("username"),
            Recording.room_id.label("room_id"),
            Recording.ended_at.label("ended_at"),
            Recording.duration_seconds.label("seconds"),
            func.row_number()
            .over(
                partition_by=(username_key, Recording.room_id),
                order_by=(Recording.ended_at.desc(), Recording.id.desc()),
            )
            .label("rank"),
        )
        .where(
            *visible,
            Recording.status.in_(FINISHED_RECORDING_STATUSES),
            Recording.ended_at.is_not(None),
            Recording.duration_seconds > 0,
        )
        .subquery()
    )
    lasts = [
        _Last(username, room_id, _aware(ended_at), int(seconds))
        for username, room_id, ended_at, seconds in (
            await session.execute(
                select(
                    ranked.c.username, ranked.c.room_id, ranked.c.ended_at, ranked.c.seconds
                ).where(ranked.c.rank == 1)
            )
        ).all()
    ]

    codes = await _pending_codes(
        session,
        settings,
        [watch.id for watch in watches if watch.owner_verified_at is None],
        now,
    )

    result: dict[uuid.UUID, WatchExtras] = {}
    for watch in watches:
        mine = [group for group in groups if _matches(watch, group.username, group.room_id)]
        last = max(
            (item for item in lasts if _matches(watch, item.username, item.room_id)),
            key=lambda item: item.ended_at,
            default=None,
        )
        code = codes.get(watch.id)
        result[watch.id] = WatchExtras(
            recording_count=sum(group.count for group in mine),
            total_recorded_seconds=sum(group.seconds for group in mine),
            last_live_duration_seconds=last.seconds if last is not None else None,
            pending_verification_code=code.code if code is not None else None,
            pending_verification_expires_at=(
                _aware(code.expires_at) if code is not None else None
            ),
        )
    return result


async def _pending_codes(
    session: AsyncSession,
    settings: AppSettings,
    watch_ids: Iterable[uuid.UUID],
    now: datetime,
) -> dict[uuid.UUID, ChannelVerification]:
    """The code GET /v1/watches/{id}/verification would show, read-only.

    Mirrors ``ChannelVerificationService._pending``: only the newest pending
    row counts, and only while it is unexpired with checks left.  Expired rows
    are left for that service to mark; this never writes.
    """
    ids = list(watch_ids)
    if not ids:
        return {}
    rows = (
        await session.scalars(
            select(ChannelVerification)
            .where(
                ChannelVerification.watch_id.in_(ids),
                ChannelVerification.status == "pending",
            )
            .order_by(ChannelVerification.created_at.desc())
        )
    ).all()
    newest: dict[uuid.UUID, ChannelVerification] = {}
    for row in rows:
        newest.setdefault(row.watch_id, row)
    return {
        watch_id: row
        for watch_id, row in newest.items()
        if _aware(row.expires_at) > now
        and row.attempts < settings.channel_verification_max_checks
    }
