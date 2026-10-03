from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.api.schemas.watches import CreateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.entitlements.service import EntitlementService
from app.application.recordings.service import RecordingService, utcnow
from app.application.watches.scheduler import WatchScheduler
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings


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


def _principal(user: User) -> AuthPrincipal:
    return AuthPrincipal(
        user_id=user.id,
        session_id=uuid.uuid4(),
        role="user",
        scopes=scopes_for_role("user"),
    )


async def _order(
    session,
    user: User,
    *,
    status: str,
    credits: int = 100,
) -> PaymentOrder:
    package = CreditPackage(
        code=f"pkg-{uuid.uuid4().hex}",
        name="B1 package",
        credits=credits,
        amount_minor=999,
        currency="USD",
        active=True,
    )
    session.add(package)
    await session.flush()
    order = PaymentOrder(
        user_id=user.id,
        package_id=package.id,
        status=status,
        credits=credits,
        amount_minor=999,
        currency="USD",
    )
    session.add(order)
    await session.commit()
    await session.refresh(order)
    return order


async def _seed_watch(
    session,
    user: User,
    *,
    auto_record: bool,
    status: str = "active",
) -> Watch:
    token = uuid.uuid4().hex
    watch = Watch(
        user_id=user.id,
        source_type="room_id",
        source_value=f"room-{token}",
        active_dedupe_key=token,
        status=status,
        live_status="offline",
        auto_record=auto_record,
        next_check_at=utcnow() if status == "active" else None,
    )
    session.add(watch)
    await session.commit()
    await session.refresh(watch)
    return watch


def test_v2_b1_entitlement_derivation_uses_purchase_and_available_balance(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b1-entitlements.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                free = await _user(session, "free-b1@example.com")
                await grant_test_credits(session, free.id, 10)
                free_snapshot = await EntitlementService(session, settings).get(free.id)
                assert free_snapshot.plan == "free"
                assert free_snapshot.has_purchased is False
                assert free_snapshot.cloud_minutes_available == 10
                assert free_snapshot.max_watches == 3
                assert free_snapshot.max_concurrent_cloud_recordings == 0
                assert free_snapshot.cloud_retention_days == 7
                assert free_snapshot.local.enabled is True
                assert free_snapshot.local.unlimited is False
                assert free_snapshot.local.minutes_remaining == 10
                assert free_snapshot.local.rewards_used_today == 0

                pro = await _user(session, "pro-b1@example.com")
                await _order(session, pro, status="paid")
                await grant_test_credits(session, pro.id, 100)
                pro_snapshot = await EntitlementService(session, settings).get(pro.id)
                assert pro_snapshot.plan == "pro"
                assert pro_snapshot.has_purchased is True
                assert pro_snapshot.cloud_minutes_available == 100
                assert pro_snapshot.max_watches == 20
                assert pro_snapshot.max_concurrent_cloud_recordings == 3
                assert pro_snapshot.cloud_retention_days == 30
                assert pro_snapshot.local.unlimited is True

                exhausted = await _user(session, "exhausted-b1@example.com")
                await _order(session, exhausted, status="paid")
                exhausted_snapshot = await EntitlementService(
                    session, settings
                ).get(exhausted.id)
                assert exhausted_snapshot.plan == "free"
                assert exhausted_snapshot.has_purchased is True
                assert exhausted_snapshot.cloud_minutes_available == 0
                assert exhausted_snapshot.max_watches == 3
                assert exhausted_snapshot.cloud_retention_days == 30
                assert exhausted_snapshot.local.unlimited is False

                partial = await _user(session, "partial-b1@example.com")
                await _order(session, partial, status="partially_refunded")
                await grant_test_credits(session, partial.id, 1)
                partial_snapshot = await EntitlementService(session, settings).get(
                    partial.id
                )
                assert partial_snapshot.plan == "pro"
                assert partial_snapshot.has_purchased is True

                refunded = await _user(session, "refunded-b1@example.com")
                await _order(session, refunded, status="refunded")
                await grant_test_credits(session, refunded.id, 100)
                refunded_snapshot = await EntitlementService(session, settings).get(
                    refunded.id
                )
                assert refunded_snapshot.plan == "free"
                assert refunded_snapshot.has_purchased is False
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b1_watch_limits_auto_record_and_existing_over_limit_accounts(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b1-watches.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                free = await _user(session, "watch-free-b1@example.com")
                service = WatchService(session, settings)

                with pytest.raises(ApplicationError) as plan_required:
                    await service.create(
                        _principal(free),
                        CreateWatchRequest(
                            source=Source(type="room_id", value="free-auto"),
                            auto_record=True,
                        ),
                    )
                assert plan_required.value.code == "PLAN_REQUIRED"
                assert plan_required.value.status_code == 403

                for _ in range(4):
                    await _seed_watch(session, free, auto_record=False)
                with pytest.raises(ApplicationError) as free_limit:
                    await service.create(
                        _principal(free),
                        CreateWatchRequest(
                            source=Source(type="room_id", value="free-fifth"),
                            auto_record=False,
                        ),
                    )
                assert free_limit.value.code == "WATCH_LIMIT_REACHED"
                assert free_limit.value.status_code == 409
                assert free_limit.value.details == {"limit": 3, "plan": "free"}
                free_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(Watch)
                        .where(
                            Watch.user_id == free.id,
                            Watch.deleted_at.is_(None),
                        )
                    )
                    or 0
                )
                assert free_count == 4

                pro = await _user(session, "watch-pro-b1@example.com")
                await _order(session, pro, status="paid")
                await grant_test_credits(session, pro.id, 100)
                pro_service = WatchService(session, settings)
                allowed = await pro_service.create(
                    _principal(pro),
                    CreateWatchRequest(
                        source=Source(type="room_id", value="pro-auto"),
                        auto_record=True,
                    ),
                )
                assert allowed.auto_record is True

                for _ in range(19):
                    await _seed_watch(session, pro, auto_record=False)
                with pytest.raises(ApplicationError) as pro_limit:
                    await pro_service.create(
                        _principal(pro),
                        CreateWatchRequest(
                            source=Source(type="room_id", value="pro-21"),
                            auto_record=False,
                        ),
                    )
                assert pro_limit.value.code == "WATCH_LIMIT_REACHED"
                assert pro_limit.value.details == {"limit": 20, "plan": "pro"}
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b1_manual_trial_cloud_recording_stays_available_but_is_single_slot(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b1-manual-trial.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = await _user(session, "manual-trial-b1@example.com")
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id, 20)

                service = RecordingService(session, settings)
                first = await service.create(
                    _principal(user),
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="trial-room-1"),
                        max_duration_seconds=60,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                assert first.status == "queued"

                with pytest.raises(ApplicationError) as limit:
                    await service.create(
                        _principal(user),
                        CreateRecordingRequest(
                            source=Source(type="room_id", value="trial-room-2"),
                            max_duration_seconds=60,
                        ),
                        idempotency_key=str(uuid.uuid4()),
                    )
                assert limit.value.code == "RATE_LIMITED"
                assert limit.value.details["limit"] == 1
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b1_pro_cloud_recording_limit_is_three(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b1-pro-recordings.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = await _user(session, "recording-pro-b1@example.com")
                await _order(session, user, status="paid")
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id, 100)

                service = RecordingService(session, settings)
                for index in range(3):
                    recording = await service.create(
                        _principal(user),
                        CreateRecordingRequest(
                            source=Source(
                                type="room_id",
                                value=f"pro-room-{index}",
                            ),
                            max_duration_seconds=60,
                        ),
                        idempotency_key=str(uuid.uuid4()),
                    )
                    assert recording.status == "queued"

                with pytest.raises(ApplicationError) as limit:
                    await service.create(
                        _principal(user),
                        CreateRecordingRequest(
                            source=Source(type="room_id", value="pro-room-4"),
                            max_duration_seconds=60,
                        ),
                        idempotency_key=str(uuid.uuid4()),
                    )
                assert limit.value.code == "RATE_LIMITED"
                assert limit.value.details["limit"] == 3
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b1_scheduler_skips_legacy_free_auto_record_and_states_are_plan_aware(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b1-scheduler.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                legacy_free = await _user(session, "legacy-free-b1@example.com")
                await grant_test_credits(session, legacy_free.id, 10)
                legacy_watch = await _seed_watch(
                    session,
                    legacy_free,
                    auto_record=True,
                )
                response = watch_response(
                    legacy_watch,
                    is_pro=False,
                    has_purchased=False,
                )
                assert response.auto_record_state == "off"

                await WatchScheduler(session, settings)._auto_record(
                    legacy_watch,
                    "legacy-free-live-room",
                )
                recording_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(Recording)
                        .where(Recording.user_id == legacy_free.id)
                    )
                    or 0
                )
                assert recording_count == 0

                exhausted = await _user(session, "paid-exhausted-b1@example.com")
                await _order(session, exhausted, status="paid")
                paused = await _seed_watch(
                    session,
                    exhausted,
                    auto_record=True,
                    status="paused_insufficient_credit",
                )
                exhausted_response = watch_response(
                    paused,
                    is_pro=False,
                    has_purchased=True,
                )
                assert (
                    exhausted_response.auto_record_state
                    == "paused_no_cloud_minutes"
                )

                pro = await _user(session, "state-pro-b1@example.com")
                await _order(session, pro, status="paid")
                await grant_test_credits(session, pro.id, 100)
                active = await _seed_watch(session, pro, auto_record=True)
                pro_response = watch_response(
                    active,
                    is_pro=True,
                    has_purchased=True,
                )
                assert pro_response.auto_record_state == "active"
        finally:
            await database.close()

    asyncio.run(run())
