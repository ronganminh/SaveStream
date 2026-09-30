from __future__ import annotations

from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class NotificationMessage:
    subject: str
    body: str
    severity: str = "info"
    dedupe_key: str | None = None


class NotificationSender(Protocol):
    async def send(self, message: NotificationMessage) -> None: ...
