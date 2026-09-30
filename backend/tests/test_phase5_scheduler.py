from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from datetime import timedelta

from sqlalchemy import func, select

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest
from app.application.recordings.service import aware, utcnow
from app.application.watches.scheduler import WatchLiveResult, WatchScheduler
from app.application.watches.service import WatchService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings


class OfflineChecker:
    async def check(self, source: Source) -> WatchLiveResult:
        return WatchLiveResult(username=source.value, room_id="room-offline", is_live=False)


class FailingChecker:
    async def check(self, source: Source) -> WatchLiveResult:
        del source
        raise RuntimeError("temporary TikTok failure")


class LiveChecker:
    def __init__(self, room_id: str) -> None:
        self.room_id = room_id

    async def check(self, source: Source) -> WatchLiveResult:
        username = source.value if source.type == "username" else "resolved"
        return WatchLiveResult(username=username, room_id=self.room_id, is_live=True)


def test_scheduler_claim_jitter_backoff_and_pause_error(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'phase5-scheduler.db'}"
            ),
            watch_error_pause_threshold=2,
            watch_jitter_ratio=0.2,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="scheduler@example.com",
                    normalized_email="scheduler@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                principal = AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
                watch = await WatchService(session, settings).create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="scheduler"),
                        auto_record=False,
                    ),
                )

                scheduler = WatchScheduler(session, settings, random_fn=lambda: 0.5)
                claims = await scheduler.claim_due()
                assert len(claims) == 1
                assert claims[0].watch_id == watch.id
                assert await scheduler.claim_due() == []

                await scheduler.process_claim(claims[0], OfflineChecker())
                await session.refresh(watch)
                assert watch.live_status == "offline"
                assert watch.failure_count == 0
                assert watch.last_checked_at is not None
                assert watch.next_check_at is not None
                assert (
                    aware(watch.next_check_at) - aware(watch.last_checked_at)
                ).total_seconds() == settings.watch_offline_check_seconds

                watch.next_check_at = utcnow() - timedelta(seconds=1)
                await session.commit()
                first_failure_claim = (await scheduler.claim_due())[0]
                await scheduler.process_claim(first_failure_claim, FailingChecker())
                await session.refresh(watch)
                assert watch.failure_count == 1
                assert watch.status == "active"
                assert (
                    aware(watch.next_check_at) - aware(watch.last_checked_at)
                ).total_seconds() == settings.watch_error_backoff_base_seconds

                watch.next_check_at = utcnow() - timedelta(seconds=1)
                await session.commit()
                second_failure_claim = (await scheduler.claim_due())[0]
                await scheduler.process_claim(second_failure_claim, FailingChecker())
                await session.refresh(watch)
                assert watch.failure_count == 2
                assert watch.status == "paused_error"
                assert watch.next_check_at is None
                assert watch.scheduler_lease_id is None
        finally:
            await database.close()

    asyncio.run(run())


def test_live_watches_dedupe_room_session_and_respect_user_concurrency(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'phase5-live.db'}"
            ),
            watch_max_concurrent_recordings_per_user=2,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="live@example.com",
                    normalized_email="live@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id)
                principal = AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
                service = WatchService(session, settings)
                first = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="creator-one"),
                        auto_record=True,
                    ),
                )
                second = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="url", value="https://example.test/live-two"),
                        auto_record=True,
                    ),
                )

                scheduler = WatchScheduler(session, settings, random_fn=lambda: 0.5)
                claims = await scheduler.claim_due()
                assert {claim.watch_id for claim in claims} == {first.id, second.id}
                for claim in claims:
                    await scheduler.process_claim(claim, LiveChecker("shared-room"))

                count = int(
                    await session.scalar(
                        select(func.count()).select_from(Recording)
                    )
                    or 0
                )
                assert count == 1

                third = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="creator-three"),
                        auto_record=True,
                    ),
                )
                capped_settings = replace(
                    settings,
                    watch_max_concurrent_recordings_per_user=1,
                )
                capped = WatchScheduler(
                    session,
                    capped_settings,
                    random_fn=lambda: 0.5,
                )
                claim = (await capped.claim_due())[0]
                assert claim.watch_id == third.id
                await capped.process_claim(claim, LiveChecker("different-room"))

                count_after_cap = int(
                    await session.scalar(
                        select(func.count()).select_from(Recording)
                    )
                    or 0
                )
                assert count_after_cap == 1

                shared = await session.scalar(
                    select(Recording).where(Recording.user_id == user.id)
                )
                assert shared is not None
                assert shared.source_type == "room_id"
                assert shared.source_value == "shared-room"
                assert shared.room_session_key is not None
        finally:
            await database.close()

    asyncio.run(run())
