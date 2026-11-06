"""Per-account channel block: ops stop one account from recording one
channel (after a creator report or takedown request). Other accounts are not
affected; a global stop for a creator is AdminCreatorBlock."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES, RecordingStatus
from app.domain.watches.state import WatchStatus
from app.infrastructure.db.admin_models import AdminComplaintCase, AdminComplaintEvent
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import ChannelAccountBlock, Watch
from app.settings import AppSettings

BLOCKED_ERROR = "channel_blocked"


def utcnow() -> datetime:
    return datetime.now(UTC)


def normalize_username(value: str | None) -> str | None:
    name = (value or "").strip().lstrip("@").casefold()
    return name or None


def blocked_error() -> ApplicationError:
    return ApplicationError(
        "CHANNEL_BLOCKED",
        "SaveStream has stopped recording this channel for your account after a report. "
        "Contact support if you think this is a mistake.",
        status_code=403,
        retryable=False,
    )


async def active_account_block(
    session: AsyncSession, user_id: uuid.UUID, username: str | None
) -> ChannelAccountBlock | None:
    name = normalize_username(username)
    if name is None:
        return None
    return await session.scalar(
        select(ChannelAccountBlock).where(
            ChannelAccountBlock.user_id == user_id,
            ChannelAccountBlock.username == name,
            ChannelAccountBlock.unblocked_at.is_(None),
        )
    )


def _watch_name(watch: Watch) -> str | None:
    return normalize_username(
        watch.resolved_username or (watch.source_value if watch.source_type == "username" else None)
    )


async def _user_watches(
    session: AsyncSession, user_id: uuid.UUID, username: str
) -> list[Watch]:
    watches = (await session.scalars(select(Watch).where(Watch.user_id == user_id))).all()
    return [watch for watch in watches if _watch_name(watch) == username]


async def block_channel_for_account(
    session: AsyncSession,
    settings: AppSettings,
    *,
    principal: AuthPrincipal,
    watch_id: str,
    reason: str,
    complaint_id: str | None,
) -> tuple[ChannelAccountBlock, list[str], list[str]]:
    """Block the watch's channel for its owner; pauses their watches of it and
    stops their active recordings. Returns (block, stopped recording ids,
    paused watch ids); the caller commits and signals the workers."""
    from app.application.admin.recordings_d3 import AdminRecordingService

    try:
        parsed_watch = uuid.UUID(watch_id)
    except ValueError as exc:
        raise ApplicationError("RESOURCE_NOT_FOUND", "Watch not found", status_code=404) from exc
    watch = await session.get(Watch, parsed_watch)
    if watch is None:
        raise ApplicationError("RESOURCE_NOT_FOUND", "Watch not found", status_code=404)
    username = _watch_name(watch)
    if username is None:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "This channel has no username yet; it cannot be blocked per account",
            status_code=422,
        )
    parsed_complaint: uuid.UUID | None = None
    if complaint_id:
        try:
            parsed_complaint = uuid.UUID(complaint_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Complaint not found", status_code=404
            ) from exc
        if await session.get(AdminComplaintCase, parsed_complaint) is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Complaint not found", status_code=404)

    now = utcnow()
    block = await session.scalar(
        select(ChannelAccountBlock).where(
            ChannelAccountBlock.user_id == watch.user_id,
            ChannelAccountBlock.username == username,
        )
    )
    if block is None:
        block = ChannelAccountBlock(
            user_id=watch.user_id,
            username=username,
            reason=reason,
            complaint_id=parsed_complaint,
            blocked_by_user_id=principal.user_id,
            created_at=now,
        )
        session.add(block)
    elif block.unblocked_at is None:
        raise ApplicationError(
            "VALIDATION_ERROR", "This channel is already blocked for this account", status_code=409
        )
    else:
        block.reason = reason
        block.complaint_id = parsed_complaint
        block.blocked_by_user_id = principal.user_id
        block.unblocked_at = None
        block.unblocked_by_user_id = None
        block.unblock_reason = None
        block.created_at = now
    await session.flush()

    paused: list[str] = []
    for item in await _user_watches(session, watch.user_id, username):
        item.blocked_at = now
        if item.deleted_at is None and item.status != WatchStatus.DISABLED.value:
            item.status = WatchStatus.PAUSED.value
            item.next_check_at = None
            item.scheduler_lease_id = None
            item.scheduler_lease_expires_at = None
            item.last_error = BLOCKED_ERROR
            paused.append(str(item.id))

    active = {status.value for status in ACTIVE_RECORDING_STATUSES}
    active.add(RecordingStatus.WAITING_FOR_CLOUD_SLOT.value)
    name = func.lower(
        func.ltrim(func.coalesce(Recording.resolved_username, Recording.source_value), "@")
    )
    recordings = (
        await session.scalars(
            select(Recording).where(
                Recording.user_id == watch.user_id,
                name == username,
                Recording.status.in_(active),
            )
        )
    ).all()
    stopped: list[str] = []
    recording_service = AdminRecordingService(session, settings)
    for recording in recordings:
        await recording_service.stop_recording(str(recording.id))
        stopped.append(str(recording.id))

    if parsed_complaint is not None:
        session.add(
            AdminComplaintEvent(
                complaint_id=parsed_complaint,
                actor_user_id=principal.user_id,
                action="channel_account_blocked",
                note=reason,
                metadata_json={
                    "user_id": str(watch.user_id),
                    "username": username,
                    "stopped_recordings": stopped,
                    "paused_watches": paused,
                },
                created_at=now,
            )
        )
    await session.flush()
    return block, stopped, paused


async def unblock_channel_for_account(
    session: AsyncSession,
    *,
    principal: AuthPrincipal,
    block_id: str,
    reason: str,
) -> ChannelAccountBlock:
    try:
        parsed = uuid.UUID(block_id)
    except ValueError as exc:
        raise ApplicationError("RESOURCE_NOT_FOUND", "Block not found", status_code=404) from exc
    block = await session.get(ChannelAccountBlock, parsed)
    if block is None:
        raise ApplicationError("RESOURCE_NOT_FOUND", "Block not found", status_code=404)
    if block.unblocked_at is not None:
        raise ApplicationError("VALIDATION_ERROR", "Block is already inactive", status_code=409)
    now = utcnow()
    block.unblocked_at = now
    block.unblocked_by_user_id = principal.user_id
    block.unblock_reason = reason
    for watch in await _user_watches(session, block.user_id, block.username):
        watch.blocked_at = None
        if (
            watch.deleted_at is None
            and watch.status == WatchStatus.PAUSED.value
            and watch.last_error == BLOCKED_ERROR
        ):
            watch.status = WatchStatus.ACTIVE.value
            watch.next_check_at = now
            watch.last_error = None
    if block.complaint_id is not None:
        session.add(
            AdminComplaintEvent(
                complaint_id=block.complaint_id,
                actor_user_id=principal.user_id,
                action="channel_account_unblocked",
                note=reason,
                metadata_json={"user_id": str(block.user_id), "username": block.username},
                created_at=now,
            )
        )
    await session.flush()
    return block


async def list_account_blocks(
    session: AsyncSession, *, active_only: bool, user_id: uuid.UUID | None = None
) -> list[ChannelAccountBlock]:
    statement = select(ChannelAccountBlock).order_by(ChannelAccountBlock.created_at.desc())
    if active_only:
        statement = statement.where(ChannelAccountBlock.unblocked_at.is_(None))
    if user_id is not None:
        statement = statement.where(ChannelAccountBlock.user_id == user_id)
    return list((await session.scalars(statement.limit(500))).all())
