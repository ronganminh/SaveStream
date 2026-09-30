from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.settings import AppSettings


class QuotaService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    @staticmethod
    def _error(name: str, limit: int) -> ApplicationError:
        return ApplicationError(
            "RATE_LIMITED",
            "Account quota exceeded",
            status_code=429,
            retryable=False,
            details={"quota": name, "limit": limit},
        )

    async def check_watch_create(self, user_id: uuid.UUID) -> None:
        limit = self.settings.quota_max_watches_per_user
        if limit <= 0:
            return
        count = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Watch)
                .where(
                    Watch.user_id == user_id,
                    Watch.deleted_at.is_(None),
                )
            )
            or 0
        )
        if count >= limit:
            raise self._error("max_watches_per_user", limit)

    async def check_recording_create(self, user_id: uuid.UUID) -> None:
        active_limit = self.settings.quota_max_active_recordings_per_user
        if active_limit > 0:
            active = int(
                await self.session.scalar(
                    select(func.count())
                    .select_from(Recording)
                    .where(
                        Recording.user_id == user_id,
                        Recording.deleted_at.is_(None),
                        Recording.status.in_(
                            [status.value for status in ACTIVE_RECORDING_STATUSES]
                        ),
                    )
                )
                or 0
            )
            if active >= active_limit:
                raise self._error("max_active_recordings_per_user", active_limit)

        daily_limit = self.settings.quota_max_recordings_per_day
        if daily_limit <= 0:
            return
        now = datetime.now(timezone.utc)
        day_start = datetime(now.year, now.month, now.day, tzinfo=timezone.utc)
        daily = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.user_id == user_id,
                    Recording.created_at >= day_start,
                )
            )
            or 0
        )
        if daily >= daily_limit:
            raise self._error("max_recordings_per_day", daily_limit)
