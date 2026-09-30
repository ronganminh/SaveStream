from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import func, select

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest, UpdateWatchRequest
from app.application.credits.service import CreditAdminService
from app.application.recordings.service import utcnow
from app.application.watches.scheduler import WatchLiveResult, WatchScheduler
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from tests.credit_helpers import configure_test_pricing
from tests.identity_helpers import identity_settings


class LiveChecker:
    async def check(self, source: Source) -> WatchLiveResult:
        return WatchLiveResult(
            username=source.value,
            room_id="phase6-live-room",
            is_live=True,
        )


def test_watch_pauses_on_insufficient_credit_and_resumes_after_adjustment(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase6-watch-credit.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="watch-credit@example.com",
                    normalized_email="watch-credit@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)

                principal = AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
                service = WatchService(session, settings)
                watch = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="creditless"),
                        auto_record=True,
                    ),
                )
                claim = (await WatchScheduler(session, settings).claim_due())[0]
                await WatchScheduler(session, settings).process_claim(
                    claim,
                    LiveChecker(),
                )
                await session.refresh(watch)
                assert watch.status == "paused_insufficient_credit"
                assert watch.next_check_at is None

                recording_count = int(
                    await session.scalar(
                        select(func.count())
                        .select_from(Recording)
                        .where(Recording.user_id == user.id)
                    )
                    or 0
                )
                assert recording_count == 0

                with pytest.raises(ApplicationError) as blocked:
                    await service.resume(principal, str(watch.id))
                assert blocked.value.code == "INSUFFICIENT_CREDITS"
                assert blocked.value.status_code == 402

                await CreditAdminService(session).adjust(
                    user_id=user.id,
                    amount=1_000,
                    idempotency_key=str(uuid.uuid4()),
                    reason="test top-up",
                )
                resumed = await service.resume(principal, str(watch.id))
                assert resumed.status == "active"
                assert resumed.next_check_at is not None

                paused = await service.update(
                    principal,
                    str(watch.id),
                    UpdateWatchRequest(status="paused"),
                )
                assert paused.status == "paused"
        finally:
            await database.close()

    asyncio.run(run())
