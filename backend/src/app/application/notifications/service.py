from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Literal

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.notifications import NotificationKind
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.admin_models import AdminEmailLog
from app.infrastructure.db.models import NotificationPreference, UserNotification
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.billing_models import PaymentOrder


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def encode_cursor(notification: UserNotification) -> str:
    payload = json.dumps(
        {
            "created_at": aware(notification.created_at).isoformat(),
            "id": str(notification.id),
        },
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


@dataclass(frozen=True, slots=True)
class NotificationPage:
    items: list[UserNotification]
    next_cursor: str | None
    has_more: bool


PUSH_PREFERENCE_FIELDS = (
    "recording_started",
    "recording_ready",
    "recording_failed",
    "creator_live",
    "recording_expiring",
    "free_minutes_low",
    "marketing",
)
EMAIL_PREFERENCE_FIELDS = (
    "email_creator_live",
    "email_recording_ready",
    "email_recording_failed",
    "email_recording_expiring",
    "email_credits_low",
    "email_credits_exhausted",
)
PREFERENCE_FIELDS = PUSH_PREFERENCE_FIELDS + EMAIL_PREFERENCE_FIELDS
_DEFAULT_OFF = {"marketing"}

# Which email switch controls the email copy of each notification kind.
EMAIL_PREFERENCE_FOR_KIND: dict[str, str] = {
    "creator_live": "email_creator_live",
    "recording_ready": "email_recording_ready",
    "recording_failed": "email_recording_failed",
    "recording_missed": "email_recording_failed",
    "recording_expiring": "email_recording_expiring",
    "credits_low": "email_credits_low",
    "cloud_minutes_exhausted": "email_credits_exhausted",
}

# Available credits at or below this send one "credits low" notice a day.
LOW_CREDITS_THRESHOLD = 60


@dataclass(frozen=True, slots=True)
class NotificationPreferenceState:
    recording_started: bool = True
    recording_ready: bool = True
    recording_failed: bool = True
    creator_live: bool = True
    recording_expiring: bool = True
    free_minutes_low: bool = True
    marketing: bool = False
    email_creator_live: bool = True
    email_recording_ready: bool = True
    email_recording_failed: bool = True
    email_recording_expiring: bool = True
    email_credits_low: bool = True
    email_credits_exhausted: bool = True
    updated_at: datetime | None = None


def _state(row: NotificationPreference | None) -> NotificationPreferenceState:
    if row is None:
        return NotificationPreferenceState()
    return NotificationPreferenceState(
        **{field: getattr(row, field) for field in PREFERENCE_FIELDS},
        updated_at=row.updated_at,
    )


def preference_enabled(row: NotificationPreference | None, field: str) -> bool:
    """A missing preferences row means defaults: everything on but marketing."""
    if row is None:
        return field not in _DEFAULT_OFF
    value = getattr(row, field, None)
    return bool(value) if value is not None else field not in _DEFAULT_OFF


def email_enabled_for(row: NotificationPreference | None, kind: str) -> bool:
    field = EMAIL_PREFERENCE_FOR_KIND.get(kind)
    return field is not None and preference_enabled(row, field)


class NotificationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list(
        self,
        principal: AuthPrincipal,
        *,
        limit: int,
        cursor: str | None,
        unread_only: bool,
    ) -> NotificationPage:
        statement = select(UserNotification).where(
            UserNotification.user_id == principal.user_id
        )
        if unread_only:
            statement = statement.where(UserNotification.read_at.is_(None))
        if cursor:
            created_at, notification_id = decode_cursor(cursor)
            statement = statement.where(
                or_(
                    UserNotification.created_at < created_at,
                    and_(
                        UserNotification.created_at == created_at,
                        UserNotification.id < notification_id,
                    ),
                )
            )
        statement = statement.order_by(
            UserNotification.created_at.desc(),
            UserNotification.id.desc(),
        ).limit(limit + 1)
        rows = list((await self.session.scalars(statement)).all())
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = encode_cursor(items[-1]) if has_more and items else None
        return NotificationPage(
            items=items,
            next_cursor=next_cursor,
            has_more=has_more,
        )

    async def mark_read(
        self,
        principal: AuthPrincipal,
        notification_id: str,
        *,
        read: bool,
    ) -> UserNotification:
        try:
            parsed_id = uuid.UUID(notification_id)
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid notification id",
                status_code=400,
            ) from exc
        notification = await self.session.scalar(
            select(UserNotification).where(
                UserNotification.id == parsed_id,
                UserNotification.user_id == principal.user_id,
            )
        )
        if notification is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Notification not found",
                status_code=404,
            )
        notification.read_at = utcnow() if read else None
        await self.session.commit()
        await self.session.refresh(notification)
        return notification

    async def mark_all_read(self, principal: AuthPrincipal) -> int:
        rows = list(
            (
                await self.session.scalars(
                    select(UserNotification).where(
                        UserNotification.user_id == principal.user_id,
                        UserNotification.read_at.is_(None),
                    )
                )
            ).all()
        )
        if not rows:
            return 0
        now = utcnow()
        for notification in rows:
            notification.read_at = now
        await self.session.commit()
        return len(rows)

    async def get_preferences(
        self,
        principal: AuthPrincipal,
    ) -> NotificationPreferenceState:
        return _state(await self.session.get(NotificationPreference, principal.user_id))

    async def update_preferences(
        self,
        principal: AuthPrincipal,
        **changes: bool | None,
    ) -> NotificationPreferenceState:
        unknown = set(changes) - set(PREFERENCE_FIELDS)
        if unknown:
            raise ValueError(f"Unknown notification preferences: {sorted(unknown)}")
        row = await self.session.get(NotificationPreference, principal.user_id)
        if row is None:
            row = NotificationPreference(user_id=principal.user_id)
            self.session.add(row)
            await self.session.flush()
        for field, value in changes.items():
            if value is not None:
                setattr(row, field, value)
        row.updated_at = utcnow()
        await self.session.commit()
        await self.session.refresh(row)
        return _state(row)


def email_dedupe_key(kind: str, resource_id: str | None, dedupe_key: str) -> str:
    """Email log key; the "LIVE" cooldown looks up keys by kind and channel."""
    return f"notify:{kind}:{resource_id or '-'}:{dedupe_key}"[:180]


async def _store_and_dispatch(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    dedupe_key: str,
    kind: str,
    title: str,
    body: str,
    resource_type: str | None,
    resource_id: str | None,
    push: bool,
    email: bool,
    push_payload: dict[str, str] | None = None,
) -> UserNotification | None:
    """App notification (in-app + push) when its switch is on, and an email
    copy when the email switch is on. Both are deduplicated, so calling this
    again for the same event does nothing new."""
    writer = OutboxWriter()
    notification: UserNotification | None = None
    created = False
    if push:
        notification_id = uuid.uuid5(uuid.NAMESPACE_URL, f"savestream:{user_id}:{dedupe_key}")
        notification = await session.get(UserNotification, notification_id)
        if notification is None:
            notification = UserNotification(
                id=notification_id,
                user_id=user_id,
                kind=kind,
                title=title,
                body=body,
                resource_type=resource_type,
                resource_id=resource_id,
                dedupe_key=dedupe_key,
            )
            session.add(notification)
            await session.flush()
            created = True
            await writer.enqueue(
                session,
                topic="notification.push",
                aggregate_type="notification",
                aggregate_id=str(notification.id),
                payload={"notification_id": str(notification.id), **(push_payload or {})},
            )
    if email:
        key = email_dedupe_key(kind, resource_id, dedupe_key)
        # Queue once: with the app notification that was just created, or,
        # when app notifications are off, while no email is logged yet.
        already = (notification is not None and not created) or (
            notification is None
            and await session.scalar(
                select(AdminEmailLog.id).where(AdminEmailLog.dedupe_key == key)
            )
            is not None
        )
        if not already:
            await writer.enqueue(
                session,
                topic="notification.email",
                aggregate_type="notification",
                aggregate_id=str(user_id),
                payload={
                    "user_id": str(user_id),
                    "kind": kind,
                    "resource_type": resource_type or "",
                    "resource_id": resource_id or "",
                    "dedupe_key": key,
                },
            )
    return notification


def _notification_definition(
    recording: Recording,
    event_type: str,
) -> tuple[NotificationKind, str, str] | None:
    source = recording.resolved_username or recording.source_value
    handle = f"@{source.lstrip('@')}" if source else "This channel"
    if event_type == "recording.started":
        return (
            "recording_started",
            "Recording started",
            f"{handle} is live and recording has started.",
        )
    if event_type == "recording.completed":
        return (
            "recording_ready",
            "Recording ready",
            f"{handle} finished recording and the recording is ready.",
        )
    if event_type == "recording.failed":
        return (
            "recording_failed",
            "Recording ended",
            f"{handle} recording failed. Open the recording for details.",
        )
    if event_type == "recording.stopped":
        return (
            "recording_failed",
            "Recording ended",
            f"{handle} recording stopped before completion.",
        )
    if event_type == "recording.missed_no_cloud_slot":
        return (
            "recording_missed",
            "Recording missed",
            f"{handle} ended before a cloud recording slot became available.",
        )
    return None


async def ensure_recording_notification(
    session: AsyncSession,
    recording: Recording,
    event_type: str,
) -> UserNotification | None:
    definition = _notification_definition(recording, event_type)
    if definition is None:
        return None
    kind, title, body = definition
    preferences = await session.get(NotificationPreference, recording.user_id)
    push_field = {
        "recording_started": "recording_started",
        "recording_ready": "recording_ready",
        "recording_failed": "recording_failed",
    }.get(kind)
    return await _store_and_dispatch(
        session,
        user_id=recording.user_id,
        dedupe_key=f"recording:{recording.id}:{kind}",
        kind=kind,
        title=title,
        body=body,
        resource_type="recording",
        resource_id=str(recording.id),
        push=preference_enabled(preferences, push_field) if push_field else True,
        email=email_enabled_for(preferences, kind),
    )


async def ensure_creator_live_notification(
    session: AsyncSession,
    watch: Watch,
    *,
    live_session_id: uuid.UUID,
) -> UserNotification | None:
    # The per-channel switch silences this channel on every channel.
    if not watch.notify_on_live:
        return None
    preferences = await session.get(NotificationPreference, watch.user_id)
    source = watch.resolved_username or watch.source_value
    handle = f"@{source.lstrip('@')}" if source else "This channel"
    return await _store_and_dispatch(
        session,
        user_id=watch.user_id,
        dedupe_key=f"watch:{watch.id}:creator_live:{live_session_id}",
        kind="creator_live",
        title="Creator is LIVE",
        body=f"{handle} is LIVE now.",
        resource_type="watch",
        resource_id=str(watch.id),
        push=preference_enabled(preferences, "creator_live"),
        email=email_enabled_for(preferences, "creator_live"),
    )


async def ensure_purchase_completed_notification(
    session: AsyncSession,
    order: PaymentOrder,
) -> UserNotification:
    notification = await _store_and_dispatch(
        session,
        user_id=order.user_id,
        dedupe_key=f"payment_order:{order.id}:purchase_completed",
        kind="purchase_completed",
        title="Purchase completed",
        body=f"{order.credits} cloud minutes were added to your account.",
        resource_type=None,
        resource_id=None,
        push=True,
        email=False,
    )
    assert notification is not None
    return notification


async def ensure_recording_expiring_notification(
    session: AsyncSession,
    recording: Recording,
    *,
    expires_at: datetime,
) -> UserNotification | None:
    preferences = await session.get(NotificationPreference, recording.user_id)
    return await _store_and_dispatch(
        session,
        user_id=recording.user_id,
        dedupe_key=f"recording:{recording.id}:recording_expiring",
        kind="recording_expiring",
        title="Recording expires soon",
        body="This cloud recording will expire in about 24 hours.",
        resource_type="recording",
        resource_id=str(recording.id),
        push=preference_enabled(preferences, "recording_expiring"),
        email=email_enabled_for(preferences, "recording_expiring"),
        push_payload={"expires_at": aware(expires_at).isoformat()},
    )


async def ensure_cloud_minutes_exhausted_notification(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    recording_id: uuid.UUID,
    trial: bool = False,
) -> UserNotification:
    preferences = await session.get(NotificationPreference, user_id)
    if trial:
        title = "Your free minutes are used up"
        body = (
            "Your free minutes are used up — buy a pack to keep recording. "
            "Your recordings stay available to watch and download."
        )
    else:
        title = "Cloud minutes exhausted"
        body = "Your available cloud recording minutes have reached zero."
    notification = await _store_and_dispatch(
        session,
        user_id=user_id,
        dedupe_key=f"recording:{recording_id}:cloud_minutes_exhausted",
        kind="cloud_minutes_exhausted",
        title=title,
        body=body,
        resource_type="recording",
        resource_id=str(recording_id),
        push=True,
        email=email_enabled_for(preferences, "cloud_minutes_exhausted"),
    )
    assert notification is not None
    return notification


async def ensure_credits_low_notification(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    available: int,
    usage_day: date,
) -> UserNotification | None:
    """At most one a day, when available cloud credits drop to an hour or less
    (but not zero; that is cloud_minutes_exhausted)."""
    if available <= 0 or available > LOW_CREDITS_THRESHOLD:
        return None
    preferences = await session.get(NotificationPreference, user_id)
    return await _store_and_dispatch(
        session,
        user_id=user_id,
        dedupe_key=f"credits-low:{usage_day.isoformat()}",
        kind="credits_low",
        title="Cloud credits are running low",
        body=f"You have {available} cloud recording minutes left.",
        resource_type=None,
        resource_id=None,
        push=True,
        email=email_enabled_for(preferences, "credits_low"),
    )


async def ensure_free_minutes_low_notification(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    usage_day: date,
    minutes_remaining: int,
    threshold: int,
) -> UserNotification | None:
    if minutes_remaining > threshold:
        return None
    preferences = await session.get(NotificationPreference, user_id)
    return await _store_and_dispatch(
        session,
        user_id=user_id,
        dedupe_key=f"free-minutes-low:{usage_day.isoformat()}",
        kind="free_minutes_low",
        title="Free recording minutes are low",
        body=(
            f"You have {max(minutes_remaining, 0)} free local "
            "recording minutes left today."
        ),
        resource_type=None,
        resource_id=None,
        push=preference_enabled(preferences, "free_minutes_low"),
        email=False,
    )
