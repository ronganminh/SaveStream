from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import timedelta

from sqlalchemy import select

from app.application.privacy.service import PrivacyService
from app.application.recordings.service import utcnow
from app.infrastructure.db.models import (\n    Base,\n    NotificationPreference,\n    OutboxEvent,\n    User,\n    UserNotification,\n)
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.main import create_app
from tests.identity_helpers import identity_settings


def test_phase9_privacy_export_deletion_and_retention(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'phase9-privacy.db'}"
            ),
            account_deletion_grace_days=0,
            recording_retention_days=1,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="privacy@example.com",
                    normalized_email="privacy@example.com",
                    display_name="Privacy User",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.flush()

                watch = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="creator-private",
                    status="active",
                    live_status="offline",
                    auto_record=False,
                )
                recording = Recording(
                    user_id=user.id,
                    source_type="username",
                    source_value="old-creator",
                    status="completed",
                    active_dedupe_key=None,
                    duration_seconds=10,
                    bytes_recorded=100,
                    estimated_max_cost=1,
                    actual_cost=1,
                    ended_at=utcnow() - timedelta(days=3),
                    created_at=utcnow() - timedelta(days=3),
                )
                notification = UserNotification(
                    user_id=user.id,
                    kind="recording_started",
                    title="Recording started",
                    body="@creator-private is live and recording has started.",
                    resource_type="recording",
                    resource_id=str(recording.id),
                    dedupe_key=f"recording:{recording.id}:recording_started",
                )
                notification_preferences = NotificationPreference(
                    user_id=user.id,
                    recording_started=False,
                    recording_ready=True,
                    recording_failed=True,
                )
                session.add_all([
                    watch,
                    recording,
                    notification,
                    notification_preferences,
                ])
                await session.commit()
                await session.refresh(user)
                await session.refresh(watch)
                await session.refresh(recording)

                service = PrivacyService(session)
                exported = await service.export_user(user.id)
                assert exported["profile"]["email"] == "privacy@example.com"
                assert exported["watches"][0]["source_value"] == "creator-private"
                assert exported["recordings"][0]["source_value"] == "old-creator"
                assert exported["notifications"][0]["type"] == "recording_started"
                assert (
                    exported["notification_preferences"]["recording_started"]
                    is False
                )

                retained = await service.apply_recording_retention(settings)
                assert retained == 1
                await session.commit()
                await session.refresh(recording)
                assert recording.deleted_at is not None

                user.deletion_requested_at = utcnow()
                user.is_active = False
                await session.commit()
                anonymized = await service.anonymize_due_accounts(settings)
                assert anonymized == 1
                await session.commit()
                await session.refresh(user)
                await session.refresh(watch)
                await session.refresh(recording)

                assert user.deletion_completed_at is not None
                assert user.email.endswith("@deleted.savestream.invalid")
                assert user.display_name is None
                assert watch.source_value == "deleted"
                assert watch.status == "disabled"
                assert recording.source_value == "deleted"

                remaining_notifications = list(
                    (
                        await session.scalars(
                            select(UserNotification).where(
                                UserNotification.user_id == user.id
                            )
                        )
                    ).all()
                )
                remaining_preferences = await session.get(
                    NotificationPreference,
                    user.id,
                )
                assert remaining_notifications == []
                assert remaining_preferences is None

                cleanup = list(
                    (
                        await session.scalars(
                            select(OutboxEvent).where(
                                OutboxEvent.topic == "recording.cleanup"
                            )
                        )
                    ).all()
                )
                assert cleanup
        finally:
            await database.close()

    asyncio.run(run())


def test_phase9_export_extension_stays_out_of_public_openapi() -> None:
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()
    assert "/v1/me/export" not in generated["paths"]
