"""Free trial credits record for real (owner decision 2026-10-16).

A verified account that has not bought credits may switch on Auto-record and
spend its trial credits, one recording at a time. Recording stops cleanly when
the credits run out, the balance never goes negative, and an unverified email
cannot record.
"""

from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.api.schemas.watches import CreateWatchRequest, UpdateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.credits.service import CreditAdminService, CreditService
from app.application.entitlements.service import EntitlementService
from app.application.notifications.service import (
    ensure_cloud_minutes_exhausted_notification,
)
from app.application.recordings.service import RecordingService, utcnow
from app.application.watches.scheduler import WatchScheduler
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.models import Base, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.email.templates import notification_email
from tests.credit_helpers import configure_test_pricing
from tests.identity_helpers import identity_settings

TRIAL_CREDITS = 10  # signup_credits stays 10: 10 minutes at 1 credit per minute


async def _user(session, email: str, *, verified: bool = True) -> User:
    user = User(
        email=email,
        normalized_email=email.casefold(),
        role="user",
        email_verified_at=utcnow() if verified else None,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def _trial_user(session, email: str, *, verified: bool = True) -> User:
    user = await _user(session, email, verified=verified)
    await configure_test_pricing(session, credits_per_unit=1)
    await CreditService(session).grant_signup_credits(user.id, TRIAL_CREDITS)
    await session.commit()
    return user


def _principal(user: User) -> AuthPrincipal:
    return AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))


async def _watch(session, user: User, room_id: str) -> Watch:
    watch = Watch(
        user_id=user.id,
        source_type="username",
        source_value=f"creator-{room_id}",
        active_dedupe_key=uuid.uuid4().hex,
        resolved_username=f"creator-{room_id}",
        resolved_room_id=room_id,
        status="active",
        live_status="live",
        auto_record=True,
        next_check_at=utcnow(),
    )
    session.add(watch)
    await session.commit()
    await session.refresh(watch)
    return watch


async def _recordings(session, user: User) -> list[Recording]:
    return list(
        (
            await session.scalars(
                select(Recording)
                .where(Recording.user_id == user.id)
                .order_by(Recording.created_at, Recording.id)
            )
        ).all()
    )


def _run(tmp_path, name: str, body) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                await body(session, settings)
        finally:
            await database.close()

    asyncio.run(run())


def test_trial_account_turns_on_auto_record_and_records_up_to_its_credits(
    tmp_path,
) -> None:
    async def body(session, settings) -> None:
        user = await _trial_user(session, "trial-records@example.com")
        snapshot = await EntitlementService(session, settings).get(user.id)
        assert snapshot.plan == "free"
        assert snapshot.trial_recording is True
        assert snapshot.can_auto_record is True
        assert snapshot.max_concurrent_cloud_recordings == 1

        service = WatchService(session, settings)
        created = await service.create(
            _principal(user),
            CreateWatchRequest(
                source=Source(type="room_id", value="trial-room"),
                auto_record=True,
            ),
        )
        assert created.auto_record is True
        state = watch_response(created, entitlement=snapshot).auto_record_state
        assert state == "active"

        watch = await _watch(session, user, "room-trial")
        await WatchScheduler(session, settings)._auto_record(watch, "room-trial")
        [recording] = await _recordings(session, user)
        assert recording.status == RecordingStatus.QUEUED.value
        # Capped to what 10 trial credits pay for: 10 minutes.
        assert recording.max_duration_seconds == TRIAL_CREDITS * 60
        assert recording.estimated_max_cost == TRIAL_CREDITS

    _run(tmp_path, "trial-records.db", body)


def test_trial_account_records_one_live_at_a_time(tmp_path) -> None:
    async def body(session, settings) -> None:
        user = await _trial_user(session, "trial-one-slot@example.com")
        scheduler = WatchScheduler(session, settings)
        first = await _watch(session, user, "room-one")
        second = await _watch(session, user, "room-two")
        await scheduler._auto_record(first, "room-one")
        await scheduler._auto_record(second, "room-two")

        # The first recording reserves all 10 trial credits; nothing is left
        # for a second one.
        [recording] = await _recordings(session, user)
        assert recording.source_value == "room-one"
        assert recording.status == RecordingStatus.QUEUED.value

        # Even with more unpurchased credit (e.g. a support grant) only one
        # recording runs; the next LIVE waits for the slot.
        await CreditAdminService(session).adjust(
            user_id=user.id,
            amount=500,
            idempotency_key=str(uuid.uuid4()),
            reason="test grant",
        )
        await session.refresh(second)
        await scheduler._auto_record(second, "room-two")
        statuses = {
            item.source_value: item.status for item in await _recordings(session, user)
        }
        assert statuses == {
            "room-one": RecordingStatus.QUEUED.value,
            "room-two": RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
        }

    _run(tmp_path, "trial-one-slot.db", body)


def test_trial_recording_stops_at_zero_without_negative_balance(tmp_path) -> None:
    async def body(session, settings) -> None:
        user = await _trial_user(session, "trial-runs-out@example.com")
        watch = await _watch(session, user, "room-out")
        await WatchScheduler(session, settings)._auto_record(watch, "room-out")
        [recording] = await _recordings(session, user)

        # The capture ran a few seconds past its 10-minute cap (connecting and
        # finalizing). It is billed the reservation, never more.
        credits = CreditService(session)
        charged = await credits.settle_recording(
            recording_id=recording.id,
            duration_seconds=TRIAL_CREDITS * 60 + 7,
            bytes_recorded=1_000_000,
        )
        await session.commit()
        assert charged == TRIAL_CREDITS
        balance = await credits.balance(user.id)
        assert balance.posted == 0
        assert balance.available == 0

        snapshot = await EntitlementService(session, settings).get(user.id)
        assert snapshot.can_auto_record is False
        assert snapshot.out_of_credit is True
        assert snapshot.max_concurrent_cloud_recordings == 0
        response = watch_response(watch, entitlement=snapshot)
        assert response.auto_record_state == "paused_no_cloud_minutes"

        # The next LIVE does not start a recording, and the balance stays at 0.
        await session.refresh(watch)
        await WatchScheduler(session, settings)._auto_record(watch, "room-out-2")
        assert len(await _recordings(session, user)) == 1
        assert (await credits.balance(user.id)).posted == 0

        # Turning Auto-record on again asks for a pack.
        with pytest.raises(ApplicationError) as blocked:
            await WatchService(session, settings).update(
                _principal(user),
                str(watch.id),
                UpdateWatchRequest(auto_record=True),
            )
        assert blocked.value.code == "PLAN_REQUIRED"

    _run(tmp_path, "trial-runs-out.db", body)


def test_unverified_email_cannot_record_with_trial_credits(tmp_path) -> None:
    async def body(session, settings) -> None:
        user = await _trial_user(
            session, "trial-unverified@example.com", verified=False
        )
        snapshot = await EntitlementService(session, settings).get(user.id)
        assert snapshot.cloud_minutes_available == TRIAL_CREDITS
        assert snapshot.can_auto_record is False
        assert snapshot.out_of_credit is False
        assert snapshot.max_concurrent_cloud_recordings == 0

        with pytest.raises(ApplicationError) as auto_record:
            await WatchService(session, settings).create(
                _principal(user),
                CreateWatchRequest(
                    source=Source(type="room_id", value="unverified-room"),
                    auto_record=True,
                ),
            )
        assert auto_record.value.code == "EMAIL_NOT_VERIFIED"
        assert auto_record.value.status_code == 403

        with pytest.raises(ApplicationError) as manual:
            await RecordingService(session, settings).create(
                _principal(user),
                CreateRecordingRequest(
                    source=Source(type="room_id", value="unverified-manual"),
                    max_duration_seconds=60,
                ),
                idempotency_key=str(uuid.uuid4()),
            )
        assert manual.value.code == "EMAIL_NOT_VERIFIED"

        watch = await _watch(session, user, "room-unverified")
        await WatchScheduler(session, settings)._auto_record(watch, "room-unverified")
        count = int(
            await session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(Recording.user_id == user.id)
            )
            or 0
        )
        assert count == 0
        assert (await CreditService(session).balance(user.id)).posted == TRIAL_CREDITS

    _run(tmp_path, "trial-unverified.db", body)


def test_trial_credits_are_granted_once_per_account(tmp_path) -> None:
    async def body(session, settings) -> None:
        user = await _trial_user(session, "trial-once@example.com")
        await CreditService(session).grant_signup_credits(user.id, TRIAL_CREDITS)
        await session.commit()
        assert (await CreditService(session).balance(user.id)).posted == TRIAL_CREDITS

    _run(tmp_path, "trial-once.db", body)


def test_trial_used_up_notification_and_email_ask_to_buy_a_pack(tmp_path) -> None:
    async def body(session, settings) -> None:
        user = await _trial_user(session, "trial-notice@example.com")
        await ensure_cloud_minutes_exhausted_notification(
            session,
            user_id=user.id,
            recording_id=uuid.uuid4(),
            trial=True,
        )
        notice = await session.scalar(
            select(UserNotification).where(UserNotification.user_id == user.id)
        )
        assert notice is not None
        assert notice.kind == "cloud_minutes_exhausted"
        assert notice.title == "Your free minutes are used up"
        assert notice.body.startswith(
            "Your free minutes are used up — buy a pack to keep recording."
        )

    _run(tmp_path, "trial-notice.db", body)

    email = notification_email(
        "cloud_minutes_exhausted",
        handle="SaveStream",
        link="https://savestream.online/billing",
        site_url="https://savestream.online",
        unsubscribe_url="https://savestream.online/unsubscribe?token=t",
        unsubscribe_label="Out of credits",
        trial=True,
    )
    assert email is not None
    assert email.subject == "Your free minutes are used up"
    assert "buy a pack to keep recording" in email.text
    assert "https://savestream.online/billing" in email.html
