from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import timedelta

from app.application.privacy.service import PrivacyService
from app.application.recordings.retention import expires_at, retention_days
from app.application.recordings.service import utcnow
from app.api.serializers.recordings import recording_response
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from tests.identity_helpers import identity_settings


def _recording(user: User, *, age_days: int) -> Recording:
    created = utcnow() - timedelta(days=age_days)
    return Recording(
        user_id=user.id,
        source_type="username",
        source_value=f"creator-{age_days}",
        status="completed",
        active_dedupe_key=None,
        duration_seconds=60,
        bytes_recorded=1000,
        estimated_max_cost=1,
        actual_cost=1,
        ended_at=created,
        created_at=created,
    )


def test_paid_accounts_keep_recordings_30_days_and_trial_accounts_7(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'retention.db'}"),
            recording_retention_days=30,
            recording_retention_days_free=7,
        )
        assert retention_days(settings, paid=True) == 30
        assert retention_days(settings, paid=False) == 7

        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                paid = User(email="paid@example.com", normalized_email="paid@example.com", role="user")
                trial = User(email="trial@example.com", normalized_email="trial@example.com", role="user")
                package = CreditPackage(
                    code="starter", name="Starter", credits=3000, amount_minor=999, currency="USD"
                )
                session.add_all([paid, trial, package])
                await session.flush()
                session.add(
                    PaymentOrder(
                        user_id=paid.id,
                        package_id=package.id,
                        status="paid",
                        credits=3000,
                        amount_minor=999,
                        currency="USD",
                    )
                )
                paid_recent = _recording(paid, age_days=10)
                paid_old = _recording(paid, age_days=40)
                trial_recent = _recording(trial, age_days=3)
                trial_old = _recording(trial, age_days=10)
                session.add_all([paid_recent, paid_old, trial_recent, trial_old])
                await session.commit()

                removed = await PrivacyService(session).apply_recording_retention(settings)
                await session.commit()
                assert removed == 2
                for recording, deleted in (
                    (paid_recent, False),
                    (paid_old, True),
                    (trial_recent, False),
                    (trial_old, True),
                ):
                    await session.refresh(recording)
                    assert (recording.deleted_at is not None) is deleted

                response = recording_response(paid_recent, retention_days=30)
                assert response.expires_at == expires_at(paid_recent.created_at, 30)
                assert recording_response(paid_recent).expires_at is None
        finally:
            await database.close()

    asyncio.run(run())


def test_free_retention_falls_back_to_paid_value() -> None:
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        recording_retention_days=30,
        recording_retention_days_free=0,
    )
    assert retention_days(settings, paid=False) == 30
    assert retention_days(replace(settings, recording_retention_days=0), paid=True) == 0
