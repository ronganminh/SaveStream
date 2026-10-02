from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.notifications import NotificationKind
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import NotificationPreference, UserNotification
from app.infrastructure.db.recording_models import Recording


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


@dataclass(frozen=True, slots=True)
class NotificationPreferenceState:
    recording_started: bool
    recording_ready: bool
    recording_failed: bool
    updated_at: datetime | None


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
        row = await self.session.get(NotificationPreference, principal.user_id)
        if row is None:
            return NotificationPreferenceState(
                recording_started=True,
                recording_ready=True,
                recording_failed=True,
                updated_at=None,
            )
        return NotificationPreferenceState(
            recording_started=row.recording_started,
            recording_ready=row.recording_ready,
            recording_failed=row.recording_failed,
            updated_at=row.updated_at,
        )

    async def update_preferences(
        self,
        principal: AuthPrincipal,
        *,
        recording_started: bool | None,
        recording_ready: bool | None,
        recording_failed: bool | None,
    ) -> NotificationPreferenceState:
        row = await self.session.get(NotificationPreference, principal.user_id)
        if row is None:
            row = NotificationPreference(user_id=principal.user_id)
            self.session.add(row)
            await self.session.flush()
        if recording_started is not None:
            row.recording_started = recording_started
        if recording_ready is not None:
            row.recording_ready = recording_ready
        if recording_failed is not None:
            row.recording_failed = recording_failed
        row.updated_at = utcnow()
        await self.session.commit()
        await self.session.refresh(row)
        return NotificationPreferenceState(
            recording_started=row.recording_started,
            recording_ready=row.recording_ready,
            recording_failed=row.recording_failed,
            updated_at=row.updated_at,
        )


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
    if preferences is not None:
        enabled = {
            "recording_started": preferences.recording_started,
            "recording_ready": preferences.recording_ready,
            "recording_failed": preferences.recording_failed,
        }[kind]
        if not enabled:
            return None

    dedupe_key = f"recording:{recording.id}:{kind}"
    notification_id = uuid.uuid5(
        uuid.NAMESPACE_URL,
        f"savestream:{recording.user_id}:{dedupe_key}",
    )
    existing = await session.get(UserNotification, notification_id)
    if existing is not None:
        return existing

    notification = UserNotification(
        id=notification_id,
        user_id=recording.user_id,
        kind=kind,
        title=title,
        body=body,
        resource_type="recording",
        resource_id=str(recording.id),
        dedupe_key=dedupe_key,
    )
    session.add(notification)
    await session.flush()
    return notification
