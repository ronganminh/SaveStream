"""Add channel: optional "I own or manage this account, or have permission
to record it" is stored with its time and shown to admins."""

from __future__ import annotations

import asyncio
import uuid

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.recordings.service import utcnow
from app.application.watches.service import WatchService
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def test_owner_attestation_is_optional_and_timestamped(tmp_path) -> None:
    async def run():
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'attest.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="attest@example.com",
                    normalized_email="attest@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                principal = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))
                service = WatchService(session, settings)
                attested = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="my.own.channel"),
                        auto_record=False,
                        owner_attested=True,
                    ),
                )
                plain = await service.create(
                    principal,
                    CreateWatchRequest(
                        source=Source(type="username", value="another.channel"),
                        auto_record=False,
                    ),
                )
                return watch_response(attested), watch_response(plain)
        finally:
            await database.close()

    attested, plain = asyncio.run(run())
    assert attested.owner_attested_at is not None
    assert plain.owner_attested_at is None
