from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Protocol

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.models import DeviceRegistration, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch


@dataclass(frozen=True, slots=True)
class PushMessage:
    title: str
    body: str
    data: dict[str, str]


class PushTokenInvalid(Exception):
    pass


class PushDeliveryError(Exception):
    pass


class PushSender(Protocol):
    async def send(self, push_token: str, message: PushMessage) -> None: ...


class NoopPushSender:
    async def send(self, push_token: str, message: PushMessage) -> None:
        del push_token, message


def _copy(
    kind: str,
    *,
    handle: str,
    fallback_title: str,
    fallback_body: str,
) -> tuple[str, str]:
    if kind == "creator_live":
        return ("Creator is LIVE", f"{handle} is LIVE now.")
    if kind == "recording_started":
        return ("Recording started", f"Recording {handle} has started.")
    if kind == "recording_ready":
        return ("Recording ready", f"The {handle} recording is ready.")
    if kind == "recording_failed":
        return ("Recording failed", f"The {handle} recording did not complete.")
    if kind == "recording_missed":
        return (
            "Recording missed",
            f"{handle} ended before a cloud recording slot became available.",
        )
    if kind == "recording_expiring":
        return ("Recording expiring", fallback_body)
    if kind == "cloud_minutes_exhausted":
        return ("Cloud minutes exhausted", fallback_body)
    if kind == "free_minutes_low":
        return ("Free minutes running low", fallback_body)
    if kind == "purchase_completed":
        return ("Purchase completed", fallback_body)
    return fallback_title, fallback_body


class PushDeliveryService:
    def __init__(self, session: AsyncSession, sender: PushSender) -> None:
        self.session = session
        self.sender = sender

    async def deliver(self, notification_id: str) -> int:
        try:
            parsed = uuid.UUID(notification_id)
        except ValueError:
            return 0
        notification = await self.session.get(UserNotification, parsed)
        if notification is None:
            return 0

        handle = "SaveStream"
        if notification.resource_type == "watch" and notification.resource_id:
            watch_id: uuid.UUID | None
            try:
                watch_id = uuid.UUID(notification.resource_id)
            except ValueError:
                watch_id = None
            if watch_id is not None:
                watch = await self.session.get(Watch, watch_id)
                if watch is not None:
                    source = watch.resolved_username or watch.source_value
                    handle = f"@{source.lstrip('@')}" if source else "SaveStream"
        elif notification.resource_type == "recording" and notification.resource_id:
            recording_id: uuid.UUID | None
            try:
                recording_id = uuid.UUID(notification.resource_id)
            except ValueError:
                recording_id = None
            if recording_id is not None:
                recording = await self.session.get(Recording, recording_id)
                if recording is not None:
                    source = recording.resolved_username or recording.source_value
                    handle = f"@{source.lstrip('@')}" if source else "SaveStream"

        devices = list(
            (
                await self.session.scalars(
                    select(DeviceRegistration).where(
                        DeviceRegistration.user_id == notification.user_id,
                        DeviceRegistration.push_token.is_not(None),
                    )
                )
            ).all()
        )
        sent = 0
        for device in devices:
            if not device.push_token:
                continue
            title, body = _copy(
                notification.kind,
                handle=handle,
                fallback_title=notification.title,
                fallback_body=notification.body,
            )
            data: dict[str, str] = {
                "notification_id": str(notification.id),
                "type": notification.kind,
            }
            if notification.resource_type is not None:
                data["resource_type"] = notification.resource_type
            if notification.resource_id is not None:
                data["resource_id"] = notification.resource_id
            try:
                await self.sender.send(
                    device.push_token,
                    PushMessage(title=title, body=body, data=data),
                )
            except PushTokenInvalid:
                device.push_token = None
                continue
            sent += 1
        await self.session.commit()
        return sent
