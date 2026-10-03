from __future__ import annotations

import asyncio
import uuid

from sqlalchemy import select

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest
from app.application.credits.service import CreditService
from app.application.recordings.service import utcnow
from app.application.watches.scheduler import WatchLiveResult, WatchScheduler
from app.application.watches.service import WatchService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.credit_models import CreditReservation
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from tests.credit_helpers import (
    configure_test_pricing,
    grant_test_credits,
    mark_test_user_paid,
)
from tests.identity_helpers import identity_settings


class LiveChecker:
    async def check(self, source: Source) -> WatchLiveResult:
        return WatchLiveResult(username=source.value, room_id="trial-live-room", is_live=True)


async def _user_with_credits(session, credits: int) -> User:
    user = User(
        email=f"{uuid.uuid4().hex}@example.com",
        normalized_email=f"{uuid.uuid4().hex}@example.com",
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    await configure_test_pricing(session, credits_per_unit=1)
    if credits:
        await grant_test_credits(session, user.id, credits)
    return user


def test_affordable_duration_is_capped_by_balance(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'afford.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user_with_credits(session, 10)
                credits = CreditService(session)
                assert await credits.affordable_duration_seconds(
                    user_id=user.id, max_duration_seconds=14_400
                ) == 600
                assert await credits.affordable_duration_seconds(
                    user_id=user.id, max_duration_seconds=300
                ) == 300
                assert (await credits.can_afford(user_id=user.id, max_duration_seconds=14_400))[0]

                broke = await _user_with_credits(session, 0)
                assert await credits.affordable_duration_seconds(
                    user_id=broke.id, max_duration_seconds=14_400
                ) == 0
                assert not (
                    await credits.can_afford(user_id=broke.id, max_duration_seconds=14_400)
                )[0]
        finally:
            await database.close()

    asyncio.run(run())


def test_paid_balance_records_until_credits_run_out(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'trial-record.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user_with_credits(session, 10)
                await mark_test_user_paid(session, user.id)
                principal = AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
                watch = await WatchService(session, settings).create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="trialcreator"),
                        auto_record=True,
                    ),
                )
                scheduler = WatchScheduler(session, settings)
                claim = (await scheduler.claim_due())[0]
                await scheduler.process_claim(claim, LiveChecker())
                await session.refresh(watch)
                assert watch.status != "paused_insufficient_credit"

                recording = await session.scalar(
                    select(Recording).where(Recording.user_id == user.id)
                )
                assert recording is not None
                assert recording.max_duration_seconds == 600
                assert recording.estimated_max_cost == 10
                reservation = await session.scalar(
                    select(CreditReservation).where(
                        CreditReservation.recording_id == recording.id
                    )
                )
                assert reservation is not None and reservation.reserved == 10
        finally:
            await database.close()

    asyncio.run(run())
