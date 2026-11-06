"""Per-account channel block: stops one account from recording one channel."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

import pytest

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.api.schemas.watches import CreateWatchRequest, UpdateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.recordings.service import RecordingService, utcnow
from app.application.watches.account_blocks import (
    block_channel_for_account,
    unblock_channel_for_account,
)
from app.application.watches.ownership import may_record
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings


def _settings(tmp_path):
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'block.db'}"),
        channel_verification_enforced=True,
        web_require_ownership=False,
    )


async def _user(session, email: str) -> AuthPrincipal:
    user = User(email=email, normalized_email=email, role="user", email_verified_at=utcnow())
    session.add(user)
    await session.commit()
    await session.refresh(user)
    await mark_test_user_paid(session, user.id)
    await grant_test_credits(session, user.id, 500)
    return AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))


def test_block_is_per_account_and_survives_re_add(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        database = Database(settings.database_url)
        async with database.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with database.session() as session:
            await configure_test_pricing(session, credits_per_unit=1)
            owner = await _user(session, "a@example.com")
            other = await _user(session, "b@example.com")
            admin = AuthPrincipal(uuid.uuid4(), uuid.uuid4(), "admin", scopes_for_role("admin"))
            watches = WatchService(session, settings)
            request = CreateWatchRequest(
                source=Source(type="username", value="@Shop.Live"),
                auto_record=True,
                owner_attested=True,
            )
            watch = await watches.create(owner, request)
            other_watch = await watches.create(other, request)
            live = Recording(
                user_id=owner.user_id,
                source_type="username",
                source_value="shop.live",
                status="recording",
            )
            session.add(live)
            await session.commit()

            block, stopped, paused = await block_channel_for_account(
                session,
                settings,
                principal=admin,
                watch_id=str(watch.id),
                reason="Creator takedown request",
                complaint_id=None,
            )
            await session.commit()
            assert block.username == "shop.live"
            assert stopped == [str(live.id)]
            assert paused == [str(watch.id)]
            await session.refresh(watch)
            await session.refresh(live)
            assert live.status == "stop_requested"
            assert watch.status == "paused"
            assert watch_response(watch, settings=settings).blocked is True
            assert not may_record(watch, settings, client_type="web")
            assert not may_record(watch, settings, client_type=None)

            recordings = RecordingService(session, settings)
            create = CreateRecordingRequest(source=Source(type="username", value="shop.live"))
            with pytest.raises(ApplicationError) as refused:
                await recordings.create(owner, create, idempotency_key=str(uuid.uuid4()))
            assert refused.value.code == "CHANNEL_BLOCKED"
            with pytest.raises(ApplicationError) as resume:
                await watches.update(owner, str(watch.id), UpdateWatchRequest(status="active"))
            assert resume.value.code == "CHANNEL_BLOCKED"

            # Another account with the same channel is unaffected.
            await session.refresh(other_watch)
            assert other_watch.blocked_at is None
            assert may_record(other_watch, settings, client_type="web")

            # Deleting and re-adding does not lift the block.
            await watches.delete(owner, str(watch.id))
            again = await watches.create(owner, request)
            assert again.blocked_at is not None
            assert again.status == "paused"

            await unblock_channel_for_account(
                session, principal=admin, block_id=str(block.id), reason="Creator withdrew"
            )
            await session.commit()
            await session.refresh(again)
            assert again.blocked_at is None
            assert again.status == "active"
            assert may_record(again, settings, client_type="web")
        await database.close()

    asyncio.run(run())
