from __future__ import annotations

import asyncio
import logging

from app.application.notifications.ports import NotificationMessage, NotificationSender
from app.infrastructure.email.smtp import SMTPEmailSender
from app.settings import AppSettings

logger = logging.getLogger("savestream.notifications")


class LoggingNotificationSender:
    async def send(self, message: NotificationMessage) -> None:
        logger.warning(
            "notification severity=%s dedupe_key=%s subject=%s body=%s",
            message.severity,
            message.dedupe_key,
            message.subject,
            message.body,
        )


class EmailNotificationSender:
    def __init__(self, settings: AppSettings, recipient: str) -> None:
        self.sender = SMTPEmailSender(settings)
        self.recipient = recipient

    async def send(self, message: NotificationMessage) -> None:
        await asyncio.to_thread(
            self.sender.send,
            to=self.recipient,
            subject=message.subject,
            text=message.body,
        )


class CompositeNotificationSender:
    def __init__(self, senders: list[NotificationSender]) -> None:
        self.senders = senders

    async def send(self, message: NotificationMessage) -> None:
        for sender in self.senders:
            await sender.send(message)


def build_notification_sender(settings: AppSettings) -> NotificationSender:
    senders: list[NotificationSender] = [LoggingNotificationSender()]
    if settings.ops_alert_email:
        senders.append(EmailNotificationSender(settings, settings.ops_alert_email))
    return CompositeNotificationSender(senders)
