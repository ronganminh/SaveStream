from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta

from sqlalchemy import select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.recordings.service import RecordingService, RecordingStateStore, utcnow
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import RecordingArtifact, RecordingEvent
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def test_recording_create_is_idempotent_scoped_and_deduped(tmp_path):
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase4-service.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                owner = User(
                    email="owner@example.com",
                    normalized_email="owner@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                other = User(
                    email="other@example.com",
                    normalized_email="other@example.com",
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
                service = RecordingService(session, settings)
                payload = CreateRecordingRequest(
                    source=Source(type="username", value="@Creator"),
                    max_duration_seconds=60,
                )
                idem = str(uuid.uuid4())
                first = await service.create(principal, payload, idempotency_key=idem)
                replay = await service.create(principal, payload, idempotency_key=idem)
                assert replay.id == first.id
                assert first.source_value == "creator"

                try:
                    await service.create(
                        principal,
                        CreateRecordingRequest(
                            source=Source(type="username", value="different"),
                            max_duration_seconds=60,
                        ),
                        idempotency_key=idem,
                    )
                except ApplicationError as exc:
                    assert exc.code == "IDEMPOTENCY_KEY_REUSED"
                    assert exc.status_code == 409
                else:
                    raise AssertionError("changed idempotent request should fail")

                try:
                    await service.create(
                        principal,
                        payload,
                        idempotency_key=str(uuid.uuid4()),
                    )
                except ApplicationError as exc:
                    assert exc.code == "RECORDING_ALREADY_ACTIVE"
                else:
                    raise AssertionError("active duplicate should fail")

                try:
                    await service.get(other_principal, str(first.id))
                except ApplicationError as exc:
                    assert exc.code == "RESOURCE_NOT_FOUND"
                    assert exc.status_code == 404
                else:
                    raise AssertionError("cross-tenant recording access should fail")

                stopped = await service.stop(principal, str(first.id))
                assert stopped.status == "stop_requested"
                events = list(
                    (
                        await session.scalars(
                            select(RecordingEvent)
                            .where(RecordingEvent.recording_id == first.id)
                            .order_by(RecordingEvent.sequence)
                        )
                    ).all()
                )
                assert [event.sequence for event in events] == [1, 2]
                assert events[-1].event_type == "recording.stop_requested"
        finally:
            await database.close()

    asyncio.run(run())


def test_worker_lease_blocks_duplicate_delivery_and_recovers_stale(tmp_path):
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase4-lease.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                user = User(
                    email="worker@example.com",
                    normalized_email="worker@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                principal = AuthPrincipal(
                    user_id=user.id,
                    session_id=uuid.uuid4(),
                    role="user",
                    scopes=scopes_for_role("user"),
                )
                recording = await RecordingService(session, settings).create(
                    principal,
                    CreateRecordingRequest(
                        source=Source(type="room_id", value="12345")
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                store = RecordingStateStore(session, settings)
                first_claim = await store.claim(recording.id)
                assert first_claim is not None
                _, first_lease = first_claim
                assert await store.claim(recording.id) is None

                recording.heartbeat_at = utcnow() - timedelta(
                    seconds=settings.recording_stale_after_seconds + 1
                )
                await session.commit()
                second_claim = await store.claim(recording.id)
                assert second_claim is not None
                recovered, second_lease = second_claim
                assert second_lease != first_lease
                assert recovered.worker_attempts == 2
        finally:
            await database.close()

    asyncio.run(run())


def test_artifact_authorization_is_tenant_scoped(tmp_path):
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase4-artifact.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                owner = User(
                    email="a@example.com",
                    normalized_email="a@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                other = User(
                    email="b@example.com",
                    normalized_email="b@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add_all([owner, other])
                await session.commit()
                await session.refresh(owner)
                await session.refresh(other)
                owner_p = AuthPrincipal(owner.id, uuid.uuid4(), "user", scopes_for_role("user"))
                other_p = AuthPrincipal(other.id, uuid.uuid4(), "user", scopes_for_role("user"))
                service = RecordingService(session, settings)
                recording = await service.create(
                    owner_p,
                    CreateRecordingRequest(source=Source(type="room_id", value="room")),
                    idempotency_key=str(uuid.uuid4()),
                )
                artifact = RecordingArtifact(
                    recording_id=recording.id,
                    storage_key=f"users/{owner.id}/recordings/{recording.id}/video.mp4",
                    container="mp4",
                    size_bytes=123,
                    checksum_sha256="a" * 64,
                )
                session.add(artifact)
                await session.commit()
                await session.refresh(artifact)
                assert (await service.artifact(owner_p, str(artifact.id))).id == artifact.id
                try:
                    await service.artifact(other_p, str(artifact.id))
                except ApplicationError as exc:
                    assert exc.code == "RESOURCE_NOT_FOUND"
                else:
                    raise AssertionError("cross-tenant artifact access should fail")
        finally:
            await database.close()

    asyncio.run(run())
