from __future__ import annotations

import asyncio
import uuid

import pytest
from sqlalchemy import select

from app.application.admin.safety_d8 import AdminSafetyService
from app.application.creator_safety import ensure_creator_not_blocked
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.admin_models import AdminCreatorBlock
from app.infrastructure.db.models import Base, User, UserNotification
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
