from __future__ import annotations

from app.application.notifications.push import NoopPushSender, PushSender
from app.infrastructure.push.fcm import FcmPushSender
from app.settings import AppSettings


def selected_push_sender(settings: AppSettings) -> PushSender:
    if settings.push_provider == "fcm":
        return FcmPushSender(settings)
    return NoopPushSender()
