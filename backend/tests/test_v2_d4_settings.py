from __future__ import annotations

import asyncio

import pytest

from app.application.admin.settings_d4 import RuntimeSettingsService
from app.application.entitlements.service import EntitlementService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from tests.credit_helpers import grant_test_credits
from tests.identity_helpers import identity_settings


def test_d4_runtime_settings_override_cache_reset_and_entitlements(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'd4-settings.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                owner = User(
                    email="owner-d4@example.com",
                    normalized_email="owner-d4@example.com",
                    role="owner",
                )
                user = User(
                    email="user-d4@example.com",
                    normalized_email="user-d4@example.com",
                    role="user",
                )
                session.add_all([owner, user])
                await session.commit()
                await session.refresh(owner)
                await session.refresh(user)
                await grant_test_credits(session, user.id, 10)

                service = RuntimeSettingsService(session, settings)
                assert await service.integer("free_max_watches") == 3
                assert await service.integer("free_local_daily_minutes") == 10

                before, after = await service.update(
                    "free_max_watches",
                    9,
                    actor_user_id=owner.id,
                )
                assert before == 3
                assert after == 9
                await service.update(
                    "free_local_daily_minutes",
                    25,
                    actor_user_id=owner.id,
                )
                await service.update(
                    "recording_retention_days_free",
                    11,
                    actor_user_id=owner.id,
                )
                await session.commit()

                # Cache invalidation is process-local and immediate after mutation.
                second = RuntimeSettingsService(session, settings)
                assert await second.integer("free_max_watches") == 9

                snapshot = await EntitlementService(session, settings).get(user.id)
                assert snapshot.max_watches == 9
                assert snapshot.local.daily_minutes == 25
                assert snapshot.local.minutes_remaining == 25
                assert snapshot.cloud_retention_days == 11

                items = await service.list_settings()
                keys = {item["key"] for item in items}
                assert "jwt_secret" not in keys
                assert "database_url" not in keys
                assert "redis_url" not in keys
                assert "smtp_password" not in keys
                assert "payment_provider_api_key" not in keys

                with pytest.raises(ApplicationError) as hidden:
                    await service.value("jwt_secret")
                assert hidden.value.status_code == 404

                with pytest.raises(ApplicationError) as invalid:
                    await service.update(
                        "free_max_watches",
                        True,
                        actor_user_id=owner.id,
                    )
                assert invalid.value.code == "VALIDATION_ERROR"

                previous, default = await service.reset("free_max_watches")
                assert previous == 9
                assert default == 3
                await session.commit()
                assert await service.integer("free_max_watches") == 3
        finally:
            await database.close()

    asyncio.run(run())
