from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import select

from app.application.admin.safety_d8 import AdminSafetyService
from app.application.creator_safety import ensure_creator_not_blocked
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.admin_models import AdminCreatorBlock, AdminSecuritySignal
from app.infrastructure.db.local_recording_models import RewardIntent, RewardUserState
from app.infrastructure.db.models import AuthSession, Base, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from tests.identity_helpers import identity_settings


def test_d8_block_creator_pauses_stops_notifies_and_unblocks(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'd8-safety.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                admin = User(
                    email="support-d8@example.com",
                    normalized_email="support-d8@example.com",
                    role="support",
                )
                user = User(
                    email="user-d8@example.com",
                    normalized_email="user-d8@example.com",
                    role="user",
                )
                session.add_all([admin, user])
                await session.flush()

                watch = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="blockedcreator",
                    resolved_username="blockedcreator",
                    status="active",
                    live_status="live",
                    auto_record=True,
                    notify_on_live=True,
                )
                recording = Recording(
                    user_id=user.id,
                    source_type="username",
                    source_value="blockedcreator",
                    resolved_username="blockedcreator",
                    status=RecordingStatus.WAITING_FOR_CLOUD_SLOT.value,
                    quality="best",
                    container="mp4",
                )
                session.add_all([watch, recording])
                await session.commit()
                await session.refresh(admin)
                await session.refresh(user)
                await session.refresh(watch)
                await session.refresh(recording)

                principal = AuthPrincipal(
                    user_id=admin.id,
                    session_id=uuid.uuid4(),
                    role="support",
                    scopes=frozenset(
                        {
                            "admin:complaints:read",
                            "admin:complaints:write",
                        }
                    ),
                )
                service = AdminSafetyService(session, settings)
                case = await service.create_complaint(
                    principal=principal,
                    kind="copyright",
                    complainant_name="Rights Holder",
                    complainant_email="rights@example.com",
                    channel_source_type="username",
                    channel_source_value="@BlockedCreator",
                    recording_id=None,
                    summary="Copyright complaint",
                    body="Please review this creator.",
                )
                block, stopped, paused = await service.block_creator(
                    principal=principal,
                    source_type="username",
                    source_value="@BlockedCreator",
                    complaint_id=str(case.id),
                    reason="Verified complaint pending review",
                )
                await session.commit()

                assert block.source_value == "blockedcreator"
                assert stopped == [str(recording.id)]
                assert paused == [str(watch.id)]

                await session.refresh(watch)
                await session.refresh(recording)
                assert watch.status == "paused"
                assert watch.last_error == "creator_blocked"
                assert recording.status == RecordingStatus.STOPPED.value

                with pytest.raises(ApplicationError) as blocked:
                    await ensure_creator_not_blocked(
                        session,
                        source_type="username",
                        source_value="blockedcreator",
                    )
                assert blocked.value.code == "CREATOR_BLOCKED"
                assert blocked.value.status_code == 403

                notifications = list(
                    (
                        await session.scalars(
                            select(UserNotification).where(
                                UserNotification.user_id == user.id
                            )
                        )
                    ).all()
                )
                assert notifications

                timeline = await service.complaint_timeline(case.id)
                assert [event.action for event in timeline] == [
                    "created",
                    "creator_blocked",
                ]

                _, deleted, pending = await service.delete_blocked_recordings(
                    block_id=str(block.id),
                    principal=principal,
                    reason="Remove locked recording after review",
                )
                await session.commit()
                assert deleted == [str(recording.id)]
                assert pending == []
                await session.refresh(recording)
                assert recording.deleted_at is not None

                unblocked = await service.unblock_creator(
                    block_id=str(block.id),
                    principal=principal,
                    reason="Complaint review completed",
                )
                await session.commit()
                assert unblocked.unblocked_at is not None

                await session.refresh(watch)
                assert watch.status == "active"
                assert watch.last_error is None

                active_block = await session.scalar(
                    select(AdminCreatorBlock).where(
                        AdminCreatorBlock.id == block.id
                    )
                )
                assert active_block is not None
        finally:
            await database.close()

    asyncio.run(run())



def test_d8_suspicious_accounts_aggregate_real_signals(tmp_path) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'd8-suspicious.db'}"
        )
        database = Database(settings.database_url)
        now = datetime.now(timezone.utc)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                users = [
                    User(
                        email=f"risk-{index}@example.com",
                        normalized_email=f"risk-{index}@example.com",
                        role="user",
                    )
                    for index in range(3)
                ]
                session.add_all(users)
                await session.flush()

                for index, user in enumerate(users):
                    session.add(
                        AuthSession(
                            user_id=user.id,
                            token_family_id=uuid.uuid4(),
                            client_type="mobile",
                            refresh_token_hash=f"hash-{index}",
                            user_agent="test",
                            ip_address="203.0.113.9",
                            expires_at=now + timedelta(days=30),
                        )
                    )

                for _ in range(3):
                    session.add(
                        AdminSecuritySignal(
                            event_type="rate_limited",
                            ip_address="203.0.113.9",
                            details={"path": "/v1/auth/sign-in", "method": "POST"},
                        )
                    )

                for index in range(3):
                    session.add(
                        RewardIntent(
                            user_id=users[0].id,
                            purpose="extend",
                            status="invalid",
                            transaction_id=f"invalid-{index}",
                            expires_at=now + timedelta(hours=1),
                        )
                    )
                session.add(
                    RewardUserState(
                        user_id=users[0].id,
                        invalid_streak=3,
                        locked_until=now + timedelta(hours=2),
                    )
                )
                await session.commit()

                items = await AdminSafetyService(
                    session, settings
                ).suspicious_accounts(limit=100)
                target = next(
                    item
                    for item in items
                    if item["user_id"] == str(users[0].id)
                )
                assert target["rate_limit_hits_24h"] == 3
                assert target["shared_signup_ip_accounts_7d"] == 3
                assert target["reward_invalid_7d"] == 3
                assert target["reward_invalid_ratio_7d"] == 1.0
                assert set(target["reasons"]) >= {
                    "repeated_rate_limits",
                    "shared_signup_ip",
                    "high_invalid_reward_ratio",
                    "reward_locked",
                }
        finally:
            await database.close()

    asyncio.run(run())
