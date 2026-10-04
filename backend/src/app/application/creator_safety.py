from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import AdminCreatorBlock
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch


def normalize_creator_source(source_type: str, source_value: str) -> str:
    value = source_value.strip()
    if source_type == "username":
        return value.lstrip("@").casefold()
    return value


async def active_creator_block(
    session: AsyncSession,
    *,
    source_type: str,
    source_value: str,
) -> AdminCreatorBlock | None:
    normalized = normalize_creator_source(source_type, source_value)
    return await session.scalar(
        select(AdminCreatorBlock).where(
            AdminCreatorBlock.source_type == source_type,
            AdminCreatorBlock.source_value == normalized,
            AdminCreatorBlock.unblocked_at.is_(None),
        )
    )


async def ensure_creator_not_blocked(
    session: AsyncSession,
    *,
    source_type: str,
    source_value: str,
) -> None:
    block = await active_creator_block(
        session,
        source_type=source_type,
        source_value=source_value,
    )
    if block is not None:
        raise ApplicationError(
            "CREATOR_BLOCKED",
            "This creator is unavailable due to a safety restriction",
            status_code=451,
            retryable=False,
        )


async def recording_creator_block(
    session: AsyncSession,
    recording: Recording,
) -> AdminCreatorBlock | None:
    blocks = list(
        (
            await session.scalars(
                select(AdminCreatorBlock).where(
                    AdminCreatorBlock.unblocked_at.is_(None)
                )
            )
        ).all()
    )
    for block in blocks:
        if block.source_type == "username":
            candidates = {
                normalize_creator_source("username", value)
                for value in (recording.resolved_username, recording.source_value)
                if value
            }
            if block.source_value in candidates:
                return block
        elif block.source_type == "room_id":
            candidates = {
                value.strip()
                for value in (recording.room_id, recording.source_value)
                if value
            }
            if block.source_value in candidates:
                return block
        elif (
            recording.source_type == block.source_type
            and normalize_creator_source(
                recording.source_type,
                recording.source_value,
            )
            == block.source_value
        ):
            return block
    return None


async def watch_creator_block(
    session: AsyncSession,
    watch: Watch,
) -> AdminCreatorBlock | None:
    blocks = list(
        (
            await session.scalars(
                select(AdminCreatorBlock).where(
                    AdminCreatorBlock.unblocked_at.is_(None)
                )
            )
        ).all()
    )
    for block in blocks:
        if block.source_type == "username":
            candidates = {
                normalize_creator_source("username", value)
                for value in (watch.resolved_username, watch.source_value)
                if value
            }
            if block.source_value in candidates:
                return block
        elif block.source_type == "room_id":
            candidates = {
                value.strip()
                for value in (watch.resolved_room_id, watch.source_value)
                if value
            }
            if block.source_value in candidates:
                return block
        elif (
            watch.source_type == block.source_type
            and normalize_creator_source(watch.source_type, watch.source_value)
            == block.source_value
        ):
            return block
    return None
