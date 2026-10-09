from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

from sqlalchemy import func, select

from app.api.routes.v2_contract import get_app_status
from app.api.serializers.recordings import recording_response
from app.application.notifications.b6 import B6NotificationService
from app.application.notifications.service import (
    ensure_cloud_minutes_exhausted_notification,
    ensure_free_minutes_low_notification,
)
from app.application.recordings.retention import expires_at
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import (
    Base,
    User,
    UserNotification,
)
from app.infrastructure.db.recording_models import (
    Recording,
    RecordingArtifact,
)
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def _completed_recording(
    user: User,
    *,
    created_at: datetime,
    suffix: str,
    actual_cost: int = 1,
) -> Recording:
    return Recording(
        user_id=user.id,
        source_type="username",
        source_value=f"creator-{suffix}",
        status="completed",
        active_dedupe_key=None,
        duration_seconds=60,
        bytes_recorded=1234,
        estimated_max_cost=actual_cost,
        actual_cost=actual_cost,
        ended_at=created_at + timedelta(minutes=1),
        created_at=created_at,
        updated_at=created_at + timedelta(minutes=1),
    )


def test_b6_app_status_and_recording_response_use_server_config() -> None:
    async def run() -> None:
        eta = datetime(2026, 10, 5, 3, 0, tzinfo=timezone.utc)
        settings = replace(
            identity_settings("sqlite+aiosqlite:///:memory:"),
            app_min_supported_android="2.4.0",
            app_min_supported_ios="3.1.0",
            maintenance_active=True,
            maintenance_eta=eta,
            recording_retention_days=30,
            recording_retention_days_free=7,
        )
        request = SimpleNamespace(
            app=SimpleNamespace(
                state=SimpleNamespace(settings=settings),
            )
        )
        status = await get_app_status(request)
        assert status.min_supported_version.android == "2.4.0"
        assert status.min_supported_version.ios == "3.1.0"
        assert status.maintenance.active is True
        assert status.maintenance.eta == eta

        created = datetime(2026, 9, 1, 0, 0, tzinfo=timezone.utc)
        user = User(
            id=uuid.uuid4(),
            email="metadata@example.com",
            normalized_email="metadata@example.com",
            role="user",
        )
        recording = _completed_recording(
            user,
            created_at=created,
            suffix="metadata",
            actual_cost=4,
        )
        response = recording_response(recording, retention_days=30)
        assert response.engine == "cloud"
        assert response.minutes_charged == 4
        assert response.expires_at == expires_at(created, 30)
        assert response.playback_ready is False
        assert recording_response(recording, artifact_ready=True).playback_ready is True

    asyncio.run(run())


def test_b6_expiry_scan_uses_30_and_7_day_retention_once(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b6-expiry.db'}"),
            recording_retention_days=30,
            recording_retention_days_free=7,
            recording_expiring_window_hours=24,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                paid = User(
                    email="paid-b6@example.com",
                    normalized_email="paid-b6@example.com",
                    role="user",
                )
                free = User(
                    email="free-b6@example.com",
                    normalized_email="free-b6@example.com",
                    role="user",
                )
                package = CreditPackage(
                    code="starter-b6",
                    name="Starter B6",
                    credits=3_000,
                    amount_minor=999,
                    currency="USD",
                )
                session.add_all([paid, free, package])
                await session.flush()
                session.add(
                    PaymentOrder(
                        user_id=paid.id,
                        package_id=package.id,
                        status="paid",
                        credits=3_000,
                        amount_minor=999,
                        currency="USD",
                    )
                )

                now = datetime(
                    2026,
                    10,
                    4,
                    1,
                    0,
                    tzinfo=timezone.utc,
                )
                paid_recording = _completed_recording(
                    paid,
                    created_at=now - timedelta(days=29, hours=2),
                    suffix="paid",
                )
                free_recording = _completed_recording(
                    free,
                    created_at=now - timedelta(days=6, hours=2),
                    suffix="free",
                )
                session.add_all([paid_recording, free_recording])
                await session.flush()
                session.add_all(
                    [
                        RecordingArtifact(
                            recording_id=paid_recording.id,
                            kind="video",
                            container="mp4",
                            storage_key=f"b6/{paid_recording.id}.mp4",
                            size_bytes=1234,
                            checksum_sha256="a" * 64,
                        ),
                        RecordingArtifact(
                            recording_id=free_recording.id,
                            kind="video",
                            container="mp4",
                            storage_key=f"b6/{free_recording.id}.mp4",
                            size_bytes=1234,
                            checksum_sha256="b" * 64,
                        ),
                    ]
                )
                await session.commit()

                service = B6NotificationService(session, settings)
                await service.scan(now=now)
                await service.scan(now=now + timedelta(minutes=5))

                notifications = list(
                    (
                        await session.scalars(
                            select(UserNotification).where(
                                UserNotification.kind == "recording_expiring"
                            )
                        )
                    ).all()
                )
                assert len(notifications) == 2
                assert {item.resource_id for item in notifications} == {
                    str(paid_recording.id),
                    str(free_recording.id),
                }
        finally:
            await database.close()

    asyncio.run(run())


def test_b6_balance_notifications_are_idempotent(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'b6-balance.db'}")
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="balance-b6@example.com",
                    normalized_email="balance-b6@example.com",
                    role="user",
                )
                session.add(user)
                await session.commit()
                recording_id = uuid.uuid4()

                await ensure_cloud_minutes_exhausted_notification(
                    session,
                    user_id=user.id,
                    recording_id=recording_id,
                )
                await ensure_cloud_minutes_exhausted_notification(
                    session,
                    user_id=user.id,
                    recording_id=recording_id,
                )
                assert (
                    await ensure_free_minutes_low_notification(
                        session,
                        user_id=user.id,
                        usage_day=date(2026, 10, 4),
                        minutes_remaining=3,
                        threshold=2,
                    )
                    is None
                )
                await ensure_free_minutes_low_notification(
                    session,
                    user_id=user.id,
                    usage_day=date(2026, 10, 4),
                    minutes_remaining=2,
                    threshold=2,
                )
                await ensure_free_minutes_low_notification(
                    session,
                    user_id=user.id,
                    usage_day=date(2026, 10, 4),
                    minutes_remaining=1,
                    threshold=2,
                )
                await session.commit()

                counts = dict(
                    (
                        await session.execute(
                            select(
                                UserNotification.kind,
                                func.count(),
                            )
                            .where(UserNotification.user_id == user.id)
                            .group_by(UserNotification.kind)
                        )
                    ).all()
                )
                assert counts["cloud_minutes_exhausted"] == 1
                assert counts["free_minutes_low"] == 1
        finally:
            await database.close()

    asyncio.run(run())
