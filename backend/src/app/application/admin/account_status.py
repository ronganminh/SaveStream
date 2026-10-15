"""Suspend, reinstate or terminate a user account (Terms "Suspension,
removal, and termination"; AUP "Enforcement").

Effects of suspending or terminating:
* every session is revoked, and sign-in shows the suspended / terminated page
  (after a correct password, so this does not reveal which emails exist);
* monitored channels are paused (marked `account_suspended`), and recordings
  in progress or waiting are stopped;
* nothing is deleted: recordings, credits and history stay as they are.

Reinstating resumes only the channels that the suspension paused. A
terminated account cannot be reinstated here.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.admin.recordings_d3 import AdminRecordingService
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import ACTIVE_RECORDING_STATUSES, RecordingStatus
from app.domain.watches.state import WatchStatus
from app.infrastructure.db.models import AuthSession, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings

AccountStatus = Literal["active", "suspended", "terminated"]
WATCH_MARKER = "account_suspended"


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AccountStatusService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def change(
        self,
        *,
        user: User,
        status: AccountStatus,
        reason: str,
        reference: str | None,
    ) -> dict[str, object]:
        before = user.account_status
        if before == status:
            raise ApplicationError(
                "INVALID_STATE", f"The account is already {status}.", status_code=409
            )
        if before == "terminated":
            raise ApplicationError(
                "INVALID_STATE",
                "A terminated account cannot be changed.",
                status_code=409,
            )
        if user.role != "user":
            raise ApplicationError(
                "FORBIDDEN", "Admin accounts cannot be suspended here.", status_code=403
            )
        user.account_status = status
        user.account_status_reason = reason.strip()
        user.account_status_reference = (reference or "").strip() or None
        user.account_status_changed_at = utcnow()

        effects: dict[str, object] = {"before": before, "after": status}
        if status in ("suspended", "terminated"):
            effects |= await self._restrict(user)
        else:
            effects["resumed_watch_ids"] = await self._resume(user)
        await OutboxWriter().enqueue(
            self.session,
            topic="account.email",
            aggregate_type="user",
            aggregate_id=str(user.id),
            payload={
                "user_id": str(user.id),
                "kind": {"suspended": "account_suspended", "terminated": "account_terminated"}.get(
                    status, "account_reinstated"
                ),
                "changed_at": user.account_status_changed_at.isoformat(),
            },
        )
        await self.session.flush()
        return effects

    async def _restrict(self, user: User) -> dict[str, object]:
        now = utcnow()
        sessions = (
            await self.session.scalars(
                select(AuthSession).where(
                    AuthSession.user_id == user.id, AuthSession.revoked_at.is_(None)
                )
            )
        ).all()
        for auth_session in sessions:
            auth_session.revoked_at = now
            auth_session.revoked_reason = f"account_{user.account_status}"

        paused: list[str] = []
        watches = (
            await self.session.scalars(
                select(Watch).where(
                    Watch.user_id == user.id,
                    Watch.deleted_at.is_(None),
                    Watch.status != WatchStatus.DISABLED.value,
                )
            )
        ).all()
        for watch in watches:
            if watch.status == WatchStatus.PAUSED.value and watch.last_error != WATCH_MARKER:
                continue  # paused by the user; leave it paused after reinstating
            watch.status = WatchStatus.PAUSED.value
            watch.next_check_at = None
            watch.scheduler_lease_id = None
            watch.scheduler_lease_expires_at = None
            watch.last_error = WATCH_MARKER
            paused.append(str(watch.id))

        active = {item.value for item in ACTIVE_RECORDING_STATUSES}
        active.add(RecordingStatus.WAITING_FOR_CLOUD_SLOT.value)
        stopped: list[str] = []
        recordings = (
            await self.session.scalars(
                select(Recording).where(
                    Recording.user_id == user.id,
                    Recording.deleted_at.is_(None),
                    Recording.status.in_(active),
                )
            )
        ).all()
        service = AdminRecordingService(self.session, self.settings)
        for recording in recordings:
            await service.stop_recording(str(recording.id))
            stopped.append(str(recording.id))
        return {
            "revoked_sessions": len(sessions),
            "paused_watch_ids": paused,
            "stopped_recording_ids": stopped,
        }

    async def _resume(self, user: User) -> list[str]:
        watches = (
            await self.session.scalars(
                select(Watch).where(
                    Watch.user_id == user.id,
                    Watch.deleted_at.is_(None),
                    Watch.status == WatchStatus.PAUSED.value,
                    Watch.last_error == WATCH_MARKER,
                )
            )
        ).all()
        resumed: list[str] = []
        for watch in watches:
            watch.status = WatchStatus.ACTIVE.value
            watch.last_error = None
            watch.next_check_at = utcnow()
            resumed.append(str(watch.id))
        return resumed


def parse_user_id(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise ApplicationError("RESOURCE_NOT_FOUND", "User not found", status_code=404) from exc
