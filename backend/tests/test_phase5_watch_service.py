from __future__ import annotations

import asyncio
import uuid

import pytest

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest, UpdateWatchRequest
from app.application.recordings.service import utcnow
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def test_watch_crud_pause_resume_and_tenant_isolation(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase5-watch.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                owner = User(
                    email="watch-owner@example.com",
                    normalized_email="watch-owner@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                other = User(
                    email="watch-other@example.com",
                    normalized_email="watch-other@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add_all([owner, other])
                await session.commit()
                await session.refresh(owner)
                await session.refresh(other)

                principal = AuthPrincipal(
                    user_id=owner.id,
                    session_id=uuid.uuid4(),
                    role="user",
                    scopes=scopes_for_role("user"),
                )
                other_principal = AuthPrincipal(
                    user_id=other.id,
                    session_id=uuid.uuid4(),
                    role="user",
                    scopes=scopes_for_role("user"),
                )
                service = WatchService(session)
                created = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="@Creator"),
                        auto_record=True,
                    ),
                )
                assert created.source_value == "creator"
                assert created.status == "active"
                assert created.live_status == "unknown"
                assert created.next_check_at is not None

                with pytest.raises(ApplicationError) as duplicate:
                    await service.create(
                        principal,
                        CreateWatchRequest(
                            source=Source(type="username", value="creator"),
                            auto_record=False,
                        ),
                    )
                assert duplicate.value.status_code == 409

                with pytest.raises(ApplicationError) as cross_tenant:
                    await service.get(other_principal, str(created.id))
                assert cross_tenant.value.code == "RESOURCE_NOT_FOUND"

                paused = await service.update(
                    principal,
                    str(created.id),
                    UpdateWatchRequest(status="paused"),
                )
                assert paused.status == "paused"
                assert paused.next_check_at is None

                resumed = await service.resume(principal, str(created.id))
                assert resumed.status == "active"
                assert resumed.next_check_at is not None

                disabled = await service.update(
                    principal,
                    str(created.id),
                    UpdateWatchRequest(status="disabled", auto_record=False),
                )
                assert disabled.status == "disabled"
                assert disabled.auto_record is False
                assert disabled.next_check_at is None

                enabled = await service.update(
                    principal,
                    str(created.id),
                    UpdateWatchRequest(status="active"),
                )
                assert enabled.status == "active"

                await service.delete(principal, str(created.id))
                with pytest.raises(ApplicationError) as deleted:
                    await service.get(principal, str(created.id))
                assert deleted.value.code == "RESOURCE_NOT_FOUND"

                recreated = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="creator"),
                        auto_record=True,
                    ),
                )
                assert recreated.id != created.id
        finally:
            await database.close()

    asyncio.run(run())
