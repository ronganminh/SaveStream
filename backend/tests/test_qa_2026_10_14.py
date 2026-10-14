"""Regression tests for the 2026-10-14 production QA report."""

from __future__ import annotations

import asyncio
import uuid

from app.api.serializers.watches import active_recording_for, watch_response
from app.application.recordings.service import utcnow
from app.application.watches.service import WatchService
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
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


def test_live_watch_without_recording_job_is_not_reported_as_recording(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'qa-bug1.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "qa-bug1@example.com")
                watch = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="p.c.dat25",
                    active_dedupe_key=uuid.uuid4().hex,
                    resolved_username="p.c.dat25",
                    resolved_room_id="room-1",
                    status="active",
                    live_status="live",
                    auto_record=False,
                    next_check_at=utcnow(),
                )
                session.add(watch)
                await session.commit()
                await session.refresh(watch)

                service = WatchService(session, settings)
                active = await service.active_recordings(user.id)
                response = watch_response(
                    watch,
                    is_pro=False,
                    has_purchased=False,
                    active_recording=active_recording_for(watch, active),
                )
                assert response.live_status == "live"
                assert response.active_recording_id is None
                assert response.active_recording_status is None

                failed = Recording(
                    user_id=user.id,
                    source_type="room_id",
                    source_value="room-1",
                    room_id="room-1",
                    status=RecordingStatus.FAILED.value,
                    quality="best",
                    container="mp4",
                )
                session.add(failed)
                await session.commit()
                active = await service.active_recordings(user.id)
                assert active_recording_for(watch, active) is None

                recording = Recording(
                    user_id=user.id,
                    source_type="room_id",
                    source_value="room-1",
                    room_id="room-1",
                    status=RecordingStatus.RECORDING.value,
                    active_dedupe_key=uuid.uuid4().hex,
                    quality="best",
                    container="mp4",
                )
                session.add(recording)
                await session.commit()
                active = await service.active_recordings(user.id)
                response = watch_response(
                    watch,
                    is_pro=False,
                    has_purchased=False,
                    active_recording=active_recording_for(watch, active),
                )
                assert response.active_recording_id == str(recording.id)
                assert response.active_recording_status == "recording"
        finally:
            await database.close()

    asyncio.run(run())


def test_admin_manual_grant_resumes_credit_paused_watches(tmp_path) -> None:
    from fastapi.testclient import TestClient
    from sqlalchemy import select

    from app.api.dependencies import get_current_principal
    from app.domain.identity.types import AuthPrincipal, scopes_for_role
    from app.main import create_app

    database_url = f"sqlite+aiosqlite:///{tmp_path / 'qa-bug2.db'}"
    settings = identity_settings(database_url)

    async def seed() -> tuple[AuthPrincipal, str, uuid.UUID]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                admin = User(
                    email="qa-admin@example.com",
                    normalized_email="qa-admin@example.com",
                    role="admin",
                    email_verified_at=utcnow(),
                )
                session.add(admin)
                await session.commit()
                await session.refresh(admin)
                user = await _user(session, "qa-bug2@example.com")
                watch = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="creator",
                    active_dedupe_key=uuid.uuid4().hex,
                    status="paused_insufficient_credit",
                    live_status="offline",
                    auto_record=True,
                    last_error="insufficient_credits",
                )
                session.add(watch)
                await session.commit()
                await session.refresh(watch)
                principal = AuthPrincipal(
                    admin.id, uuid.uuid4(), "admin", scopes_for_role("admin")
                )
                return principal, user.email, watch.id
        finally:
            await database.close()

    principal, email, watch_id = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: principal
    with TestClient(app, base_url="https://testserver") as client:
        response = client.post(
            "/v1/admin/credits/adjustments",
            headers={"Idempotency-Key": str(uuid.uuid4())},
            json={"user_id": email, "amount": 120, "reason": "qa grant"},
        )
        assert response.status_code == 200, response.text

    async def verify() -> None:
        database = Database(database_url)
        try:
            async with database.session() as session:
                watch = await session.scalar(select(Watch).where(Watch.id == watch_id))
                assert watch is not None
                assert watch.status == "active"
                assert watch.last_error is None
        finally:
            await database.close()

    asyncio.run(verify())
