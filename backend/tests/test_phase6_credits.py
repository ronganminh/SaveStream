from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.credits.service import (
    CreditAdminService,
    CreditReconciliationService,
    CreditService,
)
from app.application.pricing.service import PricingAdminService, PricingService
from app.application.recordings.service import RecordingService, RecordingStateStore, utcnow
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.credit_models import (
    CreditAccount,
    CreditLedgerEntry,
    CreditReservation,
    PricingSnapshot,
)
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings


async def _user(session, email: str) -> User:
    user = User(
        email=email,
        normalized_email=email,
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


def test_recording_reservation_settlement_snapshot_and_retry_charge_once(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'credits-settle.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "settle@example.com")
                await configure_test_pricing(
                    session,
                    version="pricing-v1",
                    credits_per_unit=2,
                    unit_seconds=60,
                )
                await grant_test_credits(session, user.id, 100)

                recording = await RecordingService(session, settings).create(
                    _principal(user),
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="room-settle"),
                        max_duration_seconds=120,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                assert recording.estimated_max_cost == 4
                assert recording.credit_reservation_id is not None

                balance = await CreditService(session).balance(user.id)
                assert (balance.posted, balance.reserved, balance.available) == (100, 4, 96)

                reservation = await session.scalar(
                    select(CreditReservation).where(
                        CreditReservation.recording_id == recording.id
                    )
                )
                assert reservation is not None
                snapshot = await session.get(PricingSnapshot, reservation.pricing_snapshot_id)
                assert snapshot is not None
                assert snapshot.version == "pricing-v1"

                await PricingAdminService(session).create_rule(
                    version="pricing-v2",
                    policy_type="duration_units_v1",
                    policy={
                        "unit_seconds": 60,
                        "credits_per_unit": 9,
                        "minimum_credits": 0,
                    },
                    public_rules=[
                        {
                            "code": "recording_duration",
                            "description": "New test pricing",
                        }
                    ],
                    activate=True,
                )

                cost = await CreditService(session).settle_recording(
                    recording_id=recording.id,
                    duration_seconds=61,
                    bytes_recorded=1_000,
                )
                await session.commit()
                assert cost == 4

                second = await CreditService(session).settle_recording(
                    recording_id=recording.id,
                    duration_seconds=61,
                    bytes_recorded=1_000,
                )
                await session.commit()
                assert second == 4

                charge_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(CreditLedgerEntry)
                        .where(
                            CreditLedgerEntry.reference_key
                            == f"recording:{recording.id}:charge"
                        )
                    )
                    or 0
                )
                assert charge_count == 1

                await session.refresh(reservation)
                assert reservation.status == "settled"
                assert reservation.settled == 4
                assert reservation.released == 0

                after = await CreditService(session).balance(user.id)
                assert (after.posted, after.reserved, after.available) == (96, 0, 96)
        finally:
            await database.close()

    asyncio.run(run())


def test_insufficient_credit_rolls_back_recording_and_failure_releases_reservation(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'credits-release.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "release@example.com")
                await configure_test_pricing(session)

                with pytest.raises(ApplicationError) as insufficient:
                    await RecordingService(session, settings).create(
                        _principal(user),
                        CreateRecordingRequest(
                            source=Source(type="room_id", value="room-no-credit"),
                            max_duration_seconds=60,
                        ),
                        idempotency_key=str(uuid.uuid4()),
                    )
                assert insufficient.value.code == "INSUFFICIENT_CREDITS"
                assert insufficient.value.status_code == 402

                recording_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(Recording)
                        .where(Recording.user_id == user.id)
                    )
                    or 0
                )
                reservation_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(CreditReservation)
                        .where(CreditReservation.user_id == user.id)
                    )
                    or 0
                )
                assert recording_count == 0
                assert reservation_count == 0

                await grant_test_credits(session, user.id, 10)
                recording = await RecordingService(session, settings).create(
                    _principal(user),
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="room-release"),
                        max_duration_seconds=60,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                before = await CreditService(session).balance(user.id)
                assert (before.posted, before.reserved, before.available) == (10, 2, 8)

                await RecordingStateStore(session, settings).fail(
                    recording,
                    code="STREAM_UNAVAILABLE",
                    message="test failure before settlement",
                    retryable=True,
                )
                after = await CreditService(session).balance(user.id)
                assert (after.posted, after.reserved, after.available) == (10, 0, 10)

                reservation = await session.scalar(
                    select(CreditReservation).where(
                        CreditReservation.recording_id == recording.id
                    )
                )
                assert reservation is not None
                assert reservation.status == "released"
                assert reservation.released == 2
                assert reservation.settled == 0
                assert recording.actual_cost == 0
        finally:
            await database.close()

    asyncio.run(run())


def test_admin_adjustment_idempotency_nonnegative_available_and_reconciliation(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'credits-admin.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "admin-credit@example.com")
                await configure_test_pricing(session)
                admin = CreditAdminService(session)
                key = str(uuid.uuid4())
                first = await admin.adjust(
                    user_id=user.id,
                    amount=10,
                    idempotency_key=key,
                    reason="support grant",
                )
                replay = await admin.adjust(
                    user_id=user.id,
                    amount=10,
                    idempotency_key=key,
                    reason="support grant",
                )
                assert replay.id == first.id

                with pytest.raises(ApplicationError) as reused:
                    await admin.adjust(
                        user_id=user.id,
                        amount=11,
                        idempotency_key=key,
                        reason="support grant",
                    )
                assert reused.value.code == "IDEMPOTENCY_KEY_REUSED"

                recording = await RecordingService(session, settings).create(
                    _principal(user),
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="room-reserved"),
                        max_duration_seconds=240,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                assert recording.estimated_max_cost == 8

                with pytest.raises(ApplicationError) as negative:
                    await admin.adjust(
                        user_id=user.id,
                        amount=-3,
                        idempotency_key=str(uuid.uuid4()),
                        reason="would consume reserved funds",
                    )
                assert negative.value.code == "INSUFFICIENT_CREDITS"

                result = await CreditReconciliationService(session).reconcile_account(
                    user.id
                )
                assert result.consistent is True

                account = await session.scalar(
                    select(CreditAccount).where(CreditAccount.user_id == user.id)
                )
                assert account is not None
                account.posted_balance += 1
                await session.commit()

                mismatch = await CreditReconciliationService(session).reconcile_account(
                    user.id
                )
                assert mismatch.consistent is False
        finally:
            await database.close()

    asyncio.run(run())


def test_pricing_requires_explicit_active_rule(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'pricing-empty.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                with pytest.raises(ApplicationError) as missing:
                    await PricingService(session).active_rule()
                assert missing.value.code == "SERVICE_UNAVAILABLE"
                assert missing.value.status_code == 503
        finally:
            await database.close()

    asyncio.run(run())
