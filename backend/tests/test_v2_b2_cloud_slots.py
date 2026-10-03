from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import func, select

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.billing.credits import BillingCreditService
from app.application.credits.service import CreditService
from app.application.recordings.cloud_slots import CloudSlotQueueService
from app.application.recordings.service import RecordingService, RecordingStateStore, utcnow
from app.application.watches.scheduler import WatchLiveResult, WatchScheduler
from app.application.watches.service import WatchService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.domain.recordings.state import (
    ACTIVE_RECORDING_STATUSES,
    TERMINAL_RECORDING_STATUSES,
    RecordingStatus,
    transition,
)
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditLedgerEntry, CreditReservation
from app.infrastructure.db.models import Base, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings


def _principal(user: User) -> AuthPrincipal:
    return AuthPrincipal(
        user.id,
        uuid.uuid4(),
        "user",
        scopes_for_role("user"),
    )


async def _user(session, email: str) -> User:
    user = User(
        email=email,
        normalized_email=email.casefold(),
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def _pro_user(session, email: str, *, credits: int = 500) -> User:
    user = await _user(session, email)
    await configure_test_pricing(session, credits_per_unit=1)
    await mark_test_user_paid(session, user.id)
    await grant_test_credits(session, user.id, credits)
    return user


async def _watch(
    session,
    user: User,
    room_id: str,
    *,
    status: str = "active",
    live_status: str = "live",
) -> Watch:
    watch = Watch(
        user_id=user.id,
        source_type="username",
        source_value=f"creator-{room_id}",
        active_dedupe_key=uuid.uuid4().hex,
        resolved_username=f"creator-{room_id}",
        resolved_room_id=room_id,
        status=status,
        live_status=live_status,
        auto_record=True,
        next_check_at=utcnow() if status == "active" else None,
    )
    session.add(watch)
    await session.commit()
    await session.refresh(watch)
    return watch


async def _active_recording(session, user: User, label: str) -> Recording:
    row = Recording(
        user_id=user.id,
        source_type="room_id",
        source_value=f"active-{label}",
        room_id=f"active-{label}",
        status=RecordingStatus.RECORDING.value,
        active_dedupe_key=f"active-{uuid.uuid4().hex}",
        room_session_key=f"session-{uuid.uuid4().hex}",
        max_duration_seconds=60,
        quality="best",
        container="mp4",
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return row


class OfflineChecker:
    def __init__(self, room_id: str) -> None:
        self.room_id = room_id

    async def check(self, source: Source) -> WatchLiveResult:
        return WatchLiveResult(
            username=source.value,
            room_id=self.room_id,
            is_live=False,
        )


def test_v2_b2_state_machine_waiters_do_not_consume_cloud_slots() -> None:
    assert RecordingStatus.WAITING_FOR_CLOUD_SLOT not in ACTIVE_RECORDING_STATUSES
    assert RecordingStatus.WAITING_FOR_CLOUD_SLOT not in TERMINAL_RECORDING_STATUSES
    assert RecordingStatus.MISSED_NO_CLOUD_SLOT in TERMINAL_RECORDING_STATUSES
    assert (
        transition(
            RecordingStatus.WAITING_FOR_CLOUD_SLOT,
            RecordingStatus.QUEUED,
        )
        is RecordingStatus.QUEUED
    )
    assert (
        transition(
            RecordingStatus.WAITING_FOR_CLOUD_SLOT,
            RecordingStatus.MISSED_NO_CLOUD_SLOT,
        )
        is RecordingStatus.MISSED_NO_CLOUD_SLOT
    )


def test_v2_b2_scheduler_queues_fifo_after_three_pro_slots(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b2-fifo.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _pro_user(session, "b2-fifo@example.com")
                for index in range(3):
                    await _active_recording(session, user, str(index))

                first_watch = await _watch(session, user, "room-first")
                second_watch = await _watch(session, user, "room-second")
                scheduler = WatchScheduler(session, settings)
                await scheduler._auto_record(first_watch, "room-first")
                await scheduler._auto_record(second_watch, "room-second")

                waiting = list(
                    (
                        await session.scalars(
                            select(Recording)
                            .where(
                                Recording.user_id == user.id,
                                Recording.status
                                == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
                            )
                            .order_by(Recording.created_at, Recording.id)
                        )
                    ).all()
                )
                assert [item.source_value for item in waiting] == [
                    "room-first",
                    "room-second",
                ]
                queue = CloudSlotQueueService(session, settings)
                assert await queue.queue_position(waiting[0]) == 1
                assert await queue.queue_position(waiting[1]) == 2

                active_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(Recording)
                        .where(
                            Recording.user_id == user.id,
                            Recording.status.in_(
                                [item.value for item in ACTIVE_RECORDING_STATUSES]
                            ),
                        )
                    )
                    or 0
                )
                assert active_count == 3

                response = watch_response(
                    first_watch,
                    is_pro=True,
                    has_purchased=True,
                    waiting_for_cloud_slot=True,
                )
                assert response.auto_record_state == "waiting_for_cloud_slot"
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b2_offline_tick_marks_waiter_missed_without_charging(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b2-missed.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _pro_user(session, "b2-missed@example.com")
                watch = await _watch(session, user, "room-missed")
                queued = await CloudSlotQueueService(
                    session, settings
                ).queue_for_watch(watch, "room-missed")
                assert queued.credit_reservation_id is None

                watch.next_check_at = utcnow()
                await session.commit()
                scheduler = WatchScheduler(session, settings)
                claim = next(
                    item
                    for item in await scheduler.claim_due()
                    if item.watch_id == watch.id
                )
                await scheduler.process_claim(
                    claim,
                    OfflineChecker("room-missed"),
                )
                await session.refresh(queued)
                assert queued.status == RecordingStatus.MISSED_NO_CLOUD_SLOT.value
                assert queued.actual_cost == 0
                assert queued.credit_reservation_id is None
                assert queued.ended_at is not None

                notification = await session.scalar(
                    select(UserNotification).where(
                        UserNotification.user_id == user.id,
                        UserNotification.resource_id == str(queued.id),
                    )
                )
                assert notification is not None
                assert notification.kind == "recording_missed"
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b2_failure_refunds_all_credit_and_promotes_oldest_waiter(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b2-promote.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _pro_user(session, "b2-promote@example.com", credits=100)
                principal = _principal(user)
                active = await RecordingService(session, settings).create(
                    principal,
                    payload=__import__(
                        "app.api.schemas.recordings",
                        fromlist=["CreateRecordingRequest"],
                    ).CreateRecordingRequest(
                        source=Source(type="room_id", value="active-main"),
                        max_duration_seconds=10,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                await _active_recording(session, user, "two")
                await _active_recording(session, user, "three")

                first_watch = await _watch(session, user, "room-q1")
                second_watch = await _watch(session, user, "room-q2")
                queue = CloudSlotQueueService(session, settings)
                first_waiter = await queue.queue_for_watch(first_watch, "room-q1")
                second_waiter = await queue.queue_for_watch(second_watch, "room-q2")

                before = await CreditService(session).balance(user.id)
                posted_before = before.posted
                store = RecordingStateStore(session, settings)
                await store.fail(
                    active,
                    code="STREAM_UNAVAILABLE",
                    message="test failure",
                    retryable=True,
                )
                await session.refresh(active)
                await session.refresh(first_waiter)
                await session.refresh(second_waiter)

                assert active.status == RecordingStatus.FAILED.value
                assert active.actual_cost == 0
                assert (await CreditService(session).balance(user.id)).posted == posted_before
                charge = await session.scalar(
                    select(CreditLedgerEntry).where(
                        CreditLedgerEntry.reference_key
                        == f"recording:{active.id}:charge"
                    )
                )
                assert charge is None
                reservation = await session.scalar(
                    select(CreditReservation).where(
                        CreditReservation.recording_id == active.id
                    )
                )
                assert reservation is not None
                assert reservation.status == "released"

                assert first_waiter.status == RecordingStatus.QUEUED.value
                assert first_waiter.credit_reservation_id is not None
                assert second_waiter.status == RecordingStatus.WAITING_FOR_CLOUD_SLOT.value
                assert await queue.queue_position(second_waiter) == 1
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b2_verified_purchase_credit_auto_resumes_paused_watches(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b2-resume.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "b2-resume@example.com")
                watch = await _watch(
                    session,
                    user,
                    "resume-room",
                    status="paused_insufficient_credit",
                    live_status="offline",
                )
                package = CreditPackage(
                    code="b2-resume-package",
                    name="B2 resume package",
                    credits=50,
                    amount_minor=999,
                    currency="USD",
                    active=True,
                )
                session.add(package)
                await session.flush()
                order = PaymentOrder(
                    user_id=user.id,
                    package_id=package.id,
                    status="paid",
                    credits=50,
                    amount_minor=999,
                    currency="USD",
                )
                session.add(order)
                await session.commit()
                await session.refresh(order)

                service = BillingCreditService(session)
                await service.grant_purchase(
                    user_id=user.id,
                    payment_order_id=order.id,
                    credits=50,
                )
                await session.commit()
                await session.refresh(watch)
                assert watch.status == "active"
                assert watch.next_check_at is not None
                assert watch.last_error is None
                assert (await CreditService(session).balance(user.id)).posted == 50

                await service.grant_purchase(
                    user_id=user.id,
                    payment_order_id=order.id,
                    credits=50,
                )
                await session.commit()
                assert (await CreditService(session).balance(user.id)).posted == 50
        finally:
            await database.close()

    asyncio.run(run())
