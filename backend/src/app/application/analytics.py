"""Product analytics (PostHog) events sent from the server.

Events go through the outbox in the same transaction as the change they
describe, so nothing is sent for a rolled-back payment or recording, and a
PostHog outage never blocks a capture or a recording (the outbox task drops
the event after logging it).

Privacy: the distinct id is the internal user id (never the email), the
properties carry no email, token or link, and staff accounts (owner, admin,
support, finance) are left out of the numbers.
"""

from __future__ import annotations

import logging
import uuid

from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.identity.types import is_admin_role
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording, RecordingArtifact
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings, get_app_settings

logger = logging.getLogger("savestream.analytics")

ANALYTICS_TOPIC = "analytics.capture"

FUNNEL_EVENTS = frozenset(
    {
        "first_recording_started",
        "first_recording_ready",
        "purchase_completed",
    }
)


def analytics_enabled(settings: AppSettings | None = None) -> bool:
    return bool((settings or get_app_settings()).posthog_api_key)


async def enqueue_analytics_event(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    event: str,
    properties: dict[str, object],
    insert_id: str,
    settings: AppSettings | None = None,
) -> bool:
    """Queue one event for the user; False when analytics is off or the user is staff.

    `insert_id` is stable for the thing being counted (an order, a recording)
    so a retried outbox task does not count it twice in PostHog.
    """
    if event not in FUNNEL_EVENTS:
        raise ValueError(f"unknown analytics event {event!r}")
    if not analytics_enabled(settings):
        return False
    role = await session.scalar(select(User.role).where(User.id == user_id))
    if role is None or is_admin_role(role):
        return False
    await OutboxWriter().enqueue(
        session,
        topic=ANALYTICS_TOPIC,
        payload={
            "event": event,
            "distinct_id": str(user_id),
            "properties": {**properties, "source": "server"},
            "uuid": str(uuid.uuid5(uuid.NAMESPACE_URL, f"savestream:{event}:{insert_id}")),
        },
        aggregate_type="user",
        aggregate_id=str(user_id),
    )
    return True


async def is_first_started_recording(
    session: AsyncSession, *, user_id: uuid.UUID, recording_id: uuid.UUID
) -> bool:
    """True when no other recording of the user has started capturing yet."""
    other_started = await session.scalar(
        select(
            exists().where(
                Recording.user_id == user_id,
                Recording.id != recording_id,
                Recording.started_at.is_not(None),
            )
        )
    )
    return not other_started


async def is_first_ready_recording(
    session: AsyncSession, *, user_id: uuid.UUID, recording_id: uuid.UUID
) -> bool:
    """True when no other recording of the user ever got a video (deleted ones count)."""
    other_ready = await session.scalar(
        select(
            exists().where(
                RecordingArtifact.recording_id == Recording.id,
                RecordingArtifact.kind == "video",
                Recording.user_id == user_id,
                Recording.id != recording_id,
            )
        )
    )
    return not other_ready


async def _guarded(session: AsyncSession, event: str, run) -> bool:
    """Run an analytics write in a savepoint; a failure is logged, never raised.

    Analytics must not fail a payment or a recording: the savepoint keeps the
    caller's transaction usable if the write fails.
    """
    try:
        async with session.begin_nested():
            return bool(await run())
    except Exception as exc:  # noqa: BLE001
        logger.warning("analytics event skipped event=%s error=%s", event, type(exc).__name__)
        return False


async def record_first_recording_event(
    session: AsyncSession,
    recording: Recording,
    *,
    event: str,
    properties: dict[str, object],
    settings: AppSettings,
) -> bool:
    """first_recording_started / first_recording_ready, once per account."""
    first_check = (
        is_first_started_recording
        if event == "first_recording_started"
        else is_first_ready_recording
    )

    async def run() -> bool:
        if not analytics_enabled(settings):
            return False
        if not await first_check(session, user_id=recording.user_id, recording_id=recording.id):
            return False
        return await enqueue_analytics_event(
            session,
            user_id=recording.user_id,
            event=event,
            properties=properties,
            insert_id=str(recording.id),
            settings=settings,
        )

    return await _guarded(session, event, run)


async def enqueue_purchase_completed(session: AsyncSession, order: PaymentOrder) -> bool:
    if not analytics_enabled():
        return False
    return await _guarded(
        session, "purchase_completed", lambda: _purchase_completed(session, order)
    )


async def _purchase_completed(session: AsyncSession, order: PaymentOrder) -> bool:
    package = (
        await session.execute(
            select(CreditPackage.code, CreditPackage.name).where(
                CreditPackage.id == order.package_id
            )
        )
    ).first()
    earlier_paid = await session.scalar(
        select(
            exists().where(
                PaymentOrder.user_id == order.user_id,
                PaymentOrder.id != order.id,
                PaymentOrder.paid_at.is_not(None),
            )
        )
    )
    return await enqueue_analytics_event(
        session,
        user_id=order.user_id,
        event="purchase_completed",
        properties={
            # Same "pack" (package name) and package_id as the web checkout_started.
            "pack": package.name if package else "unknown",
            "pack_code": package.code if package else None,
            "package_id": str(order.package_id),
            "credits": order.credits,
            "revenue": order.amount_minor / 100,
            "currency": order.currency,
            "provider": order.provider,
            "first_purchase": not earlier_paid,
        },
        insert_id=str(order.id),
    )
