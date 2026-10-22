"""Tell owners of unverified channels to verify them before recording stops.

Runs hourly. Per user (one message for all their channels):

1. once, while the grace period runs: "Verify your channels within N days";
2. once, when 7 days or less are left;
3. once, after the due date, for channels with auto-record on:
   "Recording is paused until you verify".

Each stage sends an in-app/push notification and a required service email.
"""

from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.notifications.service import _store_and_dispatch
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings

LAST_WEEK = timedelta(days=7)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _stage(watch: Watch, now: datetime) -> int:
    due = _aware(watch.verification_due_at) if watch.verification_due_at else now
    if due <= now:
        return 3 if watch.auto_record else 0
    return 2 if due - now <= LAST_WEEK else 1


def reminder_copy(stage: int, count: int, due: datetime | None) -> tuple[str, str]:
    channels = "your channel" if count == 1 else f"your {count} channels"
    if stage == 3:
        return (
            "Recording is paused until you verify",
            f"Automatic recording is paused for {channels}. Open SaveStream, tap Verify "
            "and add the code to your TikTok bio to record again.",
        )
    when = f" by {due:%B %-d}" if due else ""
    title = "7 days left to verify your channel" if stage == 2 else "Verify your channel to keep recording"
    return (
        title,
        f"SaveStream now records only channels you've confirmed are yours. Verify {channels}"
        f"{when}: open the channel, tap Verify and add the code to your TikTok bio. "
        "It takes a minute and you can remove the code afterwards.",
    )


async def send_verification_reminders(
    session: AsyncSession,
    settings: AppSettings,
    *,
    now: datetime | None = None,
) -> int:
    """Queue due reminders; returns how many users were notified."""
    if not settings.channel_verification_enforced:
        return 0
    current = now or utcnow()
    watches = list(
        (
            await session.scalars(
                select(Watch).where(
                    Watch.deleted_at.is_(None),
                    Watch.owner_verified_at.is_(None),
                    Watch.verification_due_at.is_not(None),
                    Watch.verification_reminders_sent < 3,
                )
            )
        ).all()
    )
    by_user: dict[uuid.UUID, list[tuple[Watch, int]]] = defaultdict(list)
    for watch in watches:
        # Only channels that got a grace period (added before verification
        # existed); a new channel is verified right in the Add-channel flow.
        due_at = watch.verification_due_at
        if due_at is None or _aware(due_at) - _aware(watch.created_at) < timedelta(days=1):
            continue
        stage = _stage(watch, current)
        if stage > watch.verification_reminders_sent:
            by_user[watch.user_id].append((watch, stage))
    writer = OutboxWriter()
    for user_id, items in by_user.items():
        stage = max(stage for _, stage in items)
        due = min(
            (_aware(watch.verification_due_at) for watch, _ in items if watch.verification_due_at),
            default=None,
        )
        title, body = reminder_copy(stage, len(items), due if stage < 3 else None)
        single = items[0][0] if len(items) == 1 else None
        dedupe = f"channel_verification:{stage}:{(due or current):%Y%m%d}"
        await _store_and_dispatch(
            session,
            user_id=user_id,
            dedupe_key=dedupe,
            kind="channel_verification_needed",
            title=title,
            body=body,
            resource_type="watch" if single else None,
            resource_id=str(single.id) if single else None,
            push=True,
            email=False,
        )
        await writer.enqueue(
            session,
            topic="account.email",
            aggregate_type="user",
            aggregate_id=str(user_id),
            payload={
                "user_id": str(user_id),
                "kind": "channel_verification_needed",
                "changed_at": dedupe,
                "subject": title,
                "body": body,
            },
        )
        for watch, item_stage in items:
            watch.verification_reminders_sent = max(watch.verification_reminders_sent, item_stage)
    await session.commit()
    return len(by_user)
