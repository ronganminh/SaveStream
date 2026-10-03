from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

import pytest

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.api.schemas.watches import CreateWatchRequest
from app.application.recordings.service import RecordingService, utcnow
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import identity_settings


def test_phase9_watch_and_recording_quotas(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'phase9-quota.db'}"
            ),
            quota_max_watches_per_user=1,
            quota_max_active_recordings_per_user=1,
            quota_max_recordings_per_day=10,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="quota@example.com",
                    normalized_email="quota@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id, 100)

                principal = AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
                watches = WatchService(session, settings)
                for value in ("one", "two", "three"):
                    await watches.create(
                        principal,
                        CreateWatchRequest(
                            source=Source(type="username", value=value),
                            auto_record=False,
                        ),
                    )
                with pytest.raises(ApplicationError) as watch_quota:
                    await watches.create(
                        principal,
                        CreateWatchRequest(
                            source=Source(type="username", value="four"),
                            auto_record=False,
                        ),
                    )
                assert watch_quota.value.code == "WATCH_LIMIT_REACHED"
                assert watch_quota.value.status_code == 409
                assert watch_quota.value.details == {
                    "limit": 3,
                    "plan": "free",
                }

                recordings = RecordingService(session, settings)
                await recordings.create(
                    principal,
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="room-one"),
                        max_duration_seconds=60,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                with pytest.raises(ApplicationError) as recording_quota:
                    await recordings.create(
                        principal,
                        CreateRecordingRequest(
                            source=Source(type="room_id", value="room-two"),
                            max_duration_seconds=60,
                        ),
                        idempotency_key=str(uuid.uuid4()),
                    )
                assert recording_quota.value.code == "RATE_LIMITED"
        finally:
            await database.close()

    asyncio.run(run())
