from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.recordings.service import utcnow
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES
from app.infrastructure.db.billing_models import PaymentEvent, PaymentOrder
from app.infrastructure.db.models import OutboxEvent
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.settings import AppSettings


@dataclass(frozen=True, slots=True)
class OperationalSnapshot:
    active_recordings: int
    failed_recordings_recent: int
    pending_outbox_events: int
    unprocessed_payment_events: int
    pending_payment_orders: int
    paused_error_watches: int


@dataclass(frozen=True, slots=True)
class OperationalAlert:
    code: str
    severity: str
    value: int
    threshold: int
    message: str


class OperationsService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def snapshot(self) -> OperationalSnapshot:
        now = utcnow()
        failed_since = now - timedelta(
            seconds=self.settings.ops_failed_recording_window_seconds
        )
        active_values = [status.value for status in ACTIVE_RECORDING_STATUSES]
        active_recordings = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.status.in_(active_values),
                )
            )
            or 0
        )
        failed_recordings_recent = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.status == "failed",
                    Recording.updated_at >= failed_since,
                )
            )
            or 0
        )
        pending_outbox_events = int(
            await self.session.scalar(
                select(func.count())
                .select_from(OutboxEvent)
                .where(
                    OutboxEvent.published_at.is_(None),
                    OutboxEvent.available_at <= now,
                )
            )
            or 0
        )
        unprocessed_payment_events = int(
            await self.session.scalar(
                select(func.count())
                .select_from(PaymentEvent)
                .where(PaymentEvent.processed_at.is_(None))
            )
            or 0
        )
        pending_payment_orders = int(
            await self.session.scalar(
                select(func.count())
                .select_from(PaymentOrder)
                .where(PaymentOrder.status == "pending")
            )
            or 0
        )
        paused_error_watches = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Watch)
                .where(
                    Watch.deleted_at.is_(None),
                    Watch.status == "paused_error",
                )
            )
            or 0
        )
        return OperationalSnapshot(
            active_recordings=active_recordings,
            failed_recordings_recent=failed_recordings_recent,
            pending_outbox_events=pending_outbox_events,
            unprocessed_payment_events=unprocessed_payment_events,
            pending_payment_orders=pending_payment_orders,
            paused_error_watches=paused_error_watches,
        )


def evaluate_alerts(
    snapshot: OperationalSnapshot,
    settings: AppSettings,
) -> list[OperationalAlert]:
    checks = [
        (
            "outbox_backlog",
            snapshot.pending_outbox_events,
            settings.ops_outbox_alert_threshold,
            "Transactional outbox backlog is above threshold",
        ),
        (
            "recording_failures",
            snapshot.failed_recordings_recent,
            settings.ops_failed_recording_alert_threshold,
            "Recent recording failures are above threshold",
        ),
        (
            "payment_events_unprocessed",
            snapshot.unprocessed_payment_events,
            settings.ops_payment_event_alert_threshold,
            "Unprocessed payment events are above threshold",
        ),
        (
            "watches_paused_error",
            snapshot.paused_error_watches,
            settings.ops_paused_watch_alert_threshold,
            "Watches paused by repeated errors are above threshold",
        ),
    ]
    alerts: list[OperationalAlert] = []
    for code, value, threshold, message in checks:
        if value >= threshold:
            alerts.append(
                OperationalAlert(
                    code=code,
                    severity="warning",
                    value=value,
                    threshold=threshold,
                    message=message,
                )
            )
    return alerts
