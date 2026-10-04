from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta

from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.notifications.service import (
    ensure_recording_expiring_notification,
)
from app.application.recordings.retention import (
    expires_at,
    paid_customer_clause,
    retention_days,
)
from app.application.recordings.service import utcnow
from app.infrastructure.db.recording_models import (
    Recording,
    RecordingArtifact,
)
from app.settings import AppSettings


@dataclass(frozen=True, slots=True)
class B6NotificationScanResult:
    recording_expiring: int


class B6NotificationService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
    ) -> None:
        self.session = session
        self.settings = settings

    async def scan(
        self,
        *,
        now: datetime | None = None,
    ) -> B6NotificationScanResult:
        current = now or utcnow()
        window = timedelta(
            hours=self.settings.recording_expiring_window_hours
        )
        sent = 0
        paid_users = paid_customer_clause()

        for paid in (True, False):
            days = retention_days(self.settings, paid=paid)
            if days <= 0:
                continue
            owner = (
                Recording.user_id.in_(paid_users)
                if paid
                else Recording.user_id.not_in(paid_users)
            )
            lower = current - timedelta(days=days)
            upper = current + window - timedelta(days=days)
            rows = list(
                (
                    await self.session.scalars(
                        select(Recording).where(
                            Recording.deleted_at.is_(None),
                            Recording.status.in_(["completed", "stopped"]),
                            Recording.created_at > lower,
                            Recording.created_at <= upper,
                            owner,
                            exists().where(
                                RecordingArtifact.recording_id
                                == Recording.id,
                                RecordingArtifact.deleted_at.is_(None),
                            ),
                        )
                    )
                ).all()
            )
            for recording in rows:
                expiry = expires_at(recording.created_at, days)
                if expiry is None:
                    continue
                existing = await ensure_recording_expiring_notification(
                    self.session,
                    recording,
                    expires_at=expiry,
                )
                if existing is not None:
                    sent += 1

        await self.session.commit()
        return B6NotificationScanResult(recording_expiring=sent)
