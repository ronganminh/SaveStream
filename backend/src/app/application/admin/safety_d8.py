from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.admin.recordings_d3 import AdminRecordingService
from app.application.creator_safety import normalize_creator_source
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import (
    ACTIVE_RECORDING_STATUSES,
    TERMINAL_RECORDING_STATUSES,
    RecordingStatus,
)
from app.domain.watches.state import WatchStatus
from app.infrastructure.db.admin_models import (
    AdminComplaintCase,
    AdminComplaintEvent,
    AdminCreatorBlock,
    AdminSecuritySignal,
)
from app.infrastructure.db.local_recording_models import RewardIntent, RewardUserState
from app.infrastructure.db.models import AuthSession, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


COMPLAINT_STATUSES = {"new", "reviewing", "resolved", "rejected"}
COMPLAINT_KINDS = {"copyright", "abuse"}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(case: AdminComplaintCase) -> str:
    payload = json.dumps(
        {"created_at": _aware(case.created_at).isoformat(), "id": str(case.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


class AdminSafetyService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def create_complaint(
        self,
        *,
        principal: AuthPrincipal,
        kind: str,
        complainant_name: str,
        complainant_email: str,
        channel_source_type: str | None,
        channel_source_value: str | None,
        recording_id: str | None,
        summary: str,
        body: str,
    ) -> AdminComplaintCase:
        if kind not in COMPLAINT_KINDS:
            raise ApplicationError("VALIDATION_ERROR", "Invalid complaint kind", status_code=400)
        parsed_recording_id: uuid.UUID | None = None
        if recording_id:
            try:
                parsed_recording_id = uuid.UUID(recording_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid recording id", status_code=400
                ) from exc
            recording = await self.session.get(Recording, parsed_recording_id)
            if recording is None:
                raise ApplicationError(
                    "RESOURCE_NOT_FOUND", "Recording not found", status_code=404
                )
            if channel_source_type is None or channel_source_value is None:
                channel_source_type = recording.source_type
                channel_source_value = (
                    recording.resolved_username
                    if recording.resolved_username
                    else recording.source_value
                )

        normalized_value = (
            normalize_creator_source(channel_source_type, channel_source_value)
            if channel_source_type and channel_source_value
            else None
        )
        case = AdminComplaintCase(
            kind=kind,
            complainant_name=complainant_name.strip(),
            complainant_email=complainant_email.strip().casefold(),
            channel_source_type=channel_source_type,
            channel_source_value=normalized_value,
            recording_id=parsed_recording_id,
            summary=summary.strip(),
            body=body.strip(),
            status="new",
            created_by_user_id=principal.user_id,
        )
        self.session.add(case)
        await self.session.flush()
        self.session.add(
            AdminComplaintEvent(
                complaint_id=case.id,
                actor_user_id=principal.user_id,
                action="created",
                note="Complaint case created from an external report.",
                metadata_json={"kind": kind},
            )
        )
        await self.session.flush()
        return case

    async def list_complaints(
        self,
        *,
        limit: int,
        cursor: str | None,
        status: str | None,
        kind: str | None,
        query: str | None,
    ) -> tuple[list[AdminComplaintCase], str | None, bool]:
        statement = select(AdminComplaintCase)
        if status:
            if status not in COMPLAINT_STATUSES:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid complaint status", status_code=400
                )
            statement = statement.where(AdminComplaintCase.status == status)
        if kind:
            if kind not in COMPLAINT_KINDS:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid complaint kind", status_code=400
                )
            statement = statement.where(AdminComplaintCase.kind == kind)
        if query:
            needle = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    AdminComplaintCase.complainant_email.ilike(needle),
                    AdminComplaintCase.summary.ilike(needle),
                    AdminComplaintCase.channel_source_value.ilike(needle),
                )
            )
        if cursor:
            created_at, case_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    AdminComplaintCase.created_at < created_at,
                    and_(
                        AdminComplaintCase.created_at == created_at,
                        AdminComplaintCase.id < case_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        AdminComplaintCase.created_at.desc(),
                        AdminComplaintCase.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        page = rows[:limit]
        return (
            page,
            _encode_cursor(page[-1]) if has_more and page else None,
            has_more,
        )

    async def get_complaint(self, complaint_id: str) -> AdminComplaintCase:
        try:
            parsed = uuid.UUID(complaint_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Complaint not found", status_code=404
            ) from exc
        case = await self.session.get(AdminComplaintCase, parsed)
        if case is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Complaint not found", status_code=404
            )
        return case

    async def complaint_timeline(
        self, complaint_id: uuid.UUID
    ) -> list[AdminComplaintEvent]:
        return list(
            (
                await self.session.scalars(
                    select(AdminComplaintEvent)
                    .where(AdminComplaintEvent.complaint_id == complaint_id)
                    .order_by(AdminComplaintEvent.created_at, AdminComplaintEvent.id)
                )
            ).all()
        )

    async def update_complaint(
        self,
        *,
        complaint_id: str,
        principal: AuthPrincipal,
        status: str,
        assigned_to_user_id: str | None,
        reason: str,
    ) -> tuple[AdminComplaintCase, dict[str, object]]:
        if status not in COMPLAINT_STATUSES:
            raise ApplicationError(
                "VALIDATION_ERROR", "Invalid complaint status", status_code=400
            )
        case = await self.get_complaint(complaint_id)
        before = {
            "status": case.status,
            "assigned_to_user_id": (
                str(case.assigned_to_user_id) if case.assigned_to_user_id else None
            ),
        }
        assigned: uuid.UUID | None = None
        if assigned_to_user_id:
            try:
                assigned = uuid.UUID(assigned_to_user_id)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid assignee id", status_code=400
                ) from exc
        case.status = status
        case.assigned_to_user_id = assigned
        case.resolved_at = utcnow() if status in {"resolved", "rejected"} else None
        self.session.add(
            AdminComplaintEvent(
                complaint_id=case.id,
                actor_user_id=principal.user_id,
                action="status_updated",
                note=reason,
                metadata_json={
                    "before": before,
                    "after": {
                        "status": case.status,
                        "assigned_to_user_id": (
                            str(assigned) if assigned is not None else None
                        ),
                    },
                },
            )
        )
        await self.session.flush()
        return case, before

    async def _matching_watches(
        self, source_type: str, source_value: str
    ) -> list[Watch]:
        statement = select(Watch).where(Watch.deleted_at.is_(None))
        if source_type == "username":
            statement = statement.where(
                or_(
                    Watch.resolved_username == source_value,
                    and_(
                        Watch.source_type == "username",
                        Watch.source_value == source_value,
                    ),
                )
            )
        elif source_type == "room_id":
            statement = statement.where(
                or_(
                    Watch.resolved_room_id == source_value,
                    and_(
                        Watch.source_type == "room_id",
                        Watch.source_value == source_value,
                    ),
                )
            )
        else:
            statement = statement.where(
                Watch.source_type == source_type,
                Watch.source_value == source_value,
            )
        return list((await self.session.scalars(statement)).all())

    async def _matching_recordings(
        self, source_type: str, source_value: str
    ) -> list[Recording]:
        statement = select(Recording).where(Recording.deleted_at.is_(None))
        if source_type == "username":
            statement = statement.where(
                or_(
                    Recording.resolved_username == source_value,
                    and_(
                        Recording.source_type == "username",
                        Recording.source_value == source_value,
                    ),
                )
            )
        elif source_type == "room_id":
            statement = statement.where(
                or_(
                    Recording.room_id == source_value,
                    and_(
                        Recording.source_type == "room_id",
                        Recording.source_value == source_value,
                    ),
                )
            )
        else:
            statement = statement.where(
                Recording.source_type == source_type,
                Recording.source_value == source_value,
            )
        return list((await self.session.scalars(statement)).all())

    async def _notify_affected_users(
        self,
        *,
        block: AdminCreatorBlock,
        user_ids: set[uuid.UUID],
    ) -> None:
        for user_id in user_ids:
            notification_id = uuid.uuid5(
                uuid.NAMESPACE_URL,
                f"savestream:{user_id}:creator_block:{block.id}",
            )
            if await self.session.get(UserNotification, notification_id) is not None:
                continue
            notification = UserNotification(
                id=notification_id,
                user_id=user_id,
                kind="creator_unavailable",
                title="Channel temporarily unavailable",
                body=(
                    "A channel you follow is temporarily unavailable while "
                    "a safety report is reviewed."
                ),
                resource_type=None,
                resource_id=None,
                dedupe_key=f"creator_block:{block.id}",
            )
            self.session.add(notification)
            await self.session.flush()
            await OutboxWriter().enqueue(
                self.session,
                topic="notification.push",
                aggregate_type="notification",
                aggregate_id=str(notification.id),
                payload={"notification_id": str(notification.id)},
            )

    async def list_creator_blocks(
        self,
        *,
        active_only: bool,
        limit: int = 200,
    ) -> list[AdminCreatorBlock]:
        statement = select(AdminCreatorBlock)
        if active_only:
            statement = statement.where(AdminCreatorBlock.unblocked_at.is_(None))
        return list(
            (
                await self.session.scalars(
                    statement.order_by(
                        AdminCreatorBlock.created_at.desc(),
                        AdminCreatorBlock.id.desc(),
                    ).limit(limit)
                )
            ).all()
        )

    async def block_creator(
        self,
        *,
        principal: AuthPrincipal,
        source_type: str,
        source_value: str,
        complaint_id: str | None,
        reason: str,
    ) -> tuple[AdminCreatorBlock, list[str], list[str]]:
        normalized = normalize_creator_source(source_type, source_value)
        parsed_complaint: uuid.UUID | None = None
        if complaint_id:
            case = await self.get_complaint(complaint_id)
            parsed_complaint = case.id

        block = await self.session.scalar(
            select(AdminCreatorBlock).where(
                AdminCreatorBlock.source_type == source_type,
                AdminCreatorBlock.source_value == normalized,
            )
        )
        if block is None:
            block = AdminCreatorBlock(
                source_type=source_type,
                source_value=normalized,
                complaint_id=parsed_complaint,
                reason=reason,
                blocked_by_user_id=principal.user_id,
            )
            self.session.add(block)
        elif block.unblocked_at is None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "This creator is already blocked",
                status_code=409,
            )
        else:
            block.complaint_id = parsed_complaint
            block.reason = reason
            block.blocked_by_user_id = principal.user_id
            block.unblocked_at = None
            block.unblocked_by_user_id = None
            block.unblock_reason = None
            block.created_at = utcnow()
        await self.session.flush()

        watches = await self._matching_watches(source_type, normalized)
        paused_watch_ids: list[str] = []
        user_ids: set[uuid.UUID] = set()
        for watch in watches:
            user_ids.add(watch.user_id)
            if watch.status != WatchStatus.DISABLED.value:
                watch.status = WatchStatus.PAUSED.value
                watch.next_check_at = None
                watch.scheduler_lease_id = None
                watch.scheduler_lease_expires_at = None
                watch.last_error = "creator_blocked"
                paused_watch_ids.append(str(watch.id))

        recordings = await self._matching_recordings(source_type, normalized)
        active_values = {status.value for status in ACTIVE_RECORDING_STATUSES}
        active_values.add(RecordingStatus.WAITING_FOR_CLOUD_SLOT.value)
        stopped_recording_ids: list[str] = []
        recording_service = AdminRecordingService(self.session, self.settings)
        for recording in recordings:
            user_ids.add(recording.user_id)
            if recording.status not in active_values:
                continue
            await recording_service.stop_recording(str(recording.id))
            stopped_recording_ids.append(str(recording.id))

        await self._notify_affected_users(block=block, user_ids=user_ids)
        if parsed_complaint is not None:
            self.session.add(
                AdminComplaintEvent(
                    complaint_id=parsed_complaint,
                    actor_user_id=principal.user_id,
                    action="creator_blocked",
                    note=reason,
                    metadata_json={
                        "source_type": source_type,
                        "source_value": normalized,
                        "stopped_recordings": stopped_recording_ids,
                        "paused_watches": paused_watch_ids,
                    },
                )
            )
        await self.session.flush()
        return block, stopped_recording_ids, paused_watch_ids

    async def suspicious_accounts(
        self,
        *,
        limit: int = 200,
    ) -> list[dict[str, object]]:
        now = utcnow()
        day_start = now - timedelta(hours=24)
        week_start = now - timedelta(days=7)

        recent_users = list(
            (
                await self.session.scalars(
                    select(User)
                    .where(User.created_at >= week_start)
                    .order_by(User.created_at.desc())
                    .limit(5000)
                )
            ).all()
        )
        all_users = {
            user.id: user
            for user in (
                await self.session.scalars(
                    select(User).where(User.role == "user")
                )
            ).all()
        }

        session_rows = (
            await self.session.execute(
                select(
                    AuthSession.user_id,
                    AuthSession.ip_address,
                    AuthSession.created_at,
                ).where(
                    AuthSession.created_at >= week_start,
                    AuthSession.ip_address.is_not(None),
                )
            )
        ).all()
        ips_by_user: dict[uuid.UUID, set[str]] = {}
        users_by_ip: dict[str, set[uuid.UUID]] = {}
        recent_user_ids = {user.id for user in recent_users}
        for user_id, ip_address, _created_at in session_rows:
            if not ip_address:
                continue
            ips_by_user.setdefault(user_id, set()).add(ip_address)
            if user_id in recent_user_ids:
                users_by_ip.setdefault(ip_address, set()).add(user_id)

        rate_rows = (
            await self.session.execute(
                select(
                    AdminSecuritySignal.ip_address,
                    AdminSecuritySignal.created_at,
                ).where(
                    AdminSecuritySignal.event_type == "rate_limited",
                    AdminSecuritySignal.created_at >= day_start,
                    AdminSecuritySignal.ip_address.is_not(None),
                )
            )
        ).all()
        rate_hits_by_ip: dict[str, int] = {}
        for ip_address, _created_at in rate_rows:
            if ip_address:
                rate_hits_by_ip[ip_address] = rate_hits_by_ip.get(ip_address, 0) + 1

        reward_rows = (
            await self.session.execute(
                select(RewardIntent.user_id, RewardIntent.status).where(
                    RewardIntent.created_at >= week_start,
                    RewardIntent.status.in_(("valid", "invalid")),
                )
            )
        ).all()
        reward_counts: dict[uuid.UUID, dict[str, int]] = {}
        for user_id, status in reward_rows:
            counts = reward_counts.setdefault(user_id, {"valid": 0, "invalid": 0})
            counts[status] += 1

        reward_states = {
            state.user_id: state
            for state in (
                await self.session.scalars(select(RewardUserState))
            ).all()
        }

        candidate_ids = set(all_users)
        items: list[dict[str, object]] = []
        for user_id in candidate_ids:
            user = all_users[user_id]
            user_ips = ips_by_user.get(user_id, set())
            rate_hits = sum(rate_hits_by_ip.get(ip, 0) for ip in user_ips)
            shared_signup_accounts = max(
                (len(users_by_ip.get(ip, set())) for ip in user_ips),
                default=0,
            )
            counts = reward_counts.get(user_id, {"valid": 0, "invalid": 0})
            reward_total = counts["valid"] + counts["invalid"]
            invalid_ratio = (
                counts["invalid"] / reward_total if reward_total else 0.0
            )
            state = reward_states.get(user_id)
            locked_until = state.locked_until if state is not None else None
            invalid_streak = state.invalid_streak if state is not None else 0

            reasons: list[str] = []
            if rate_hits >= 3:
                reasons.append("repeated_rate_limits")
            if shared_signup_accounts >= 3:
                reasons.append("shared_signup_ip")
            if counts["invalid"] >= 3 and invalid_ratio >= 0.5:
                reasons.append("high_invalid_reward_ratio")
            if locked_until is not None and _aware(locked_until) > now:
                reasons.append("reward_locked")
            if invalid_streak >= 3 and "high_invalid_reward_ratio" not in reasons:
                reasons.append("reward_invalid_streak")
            if not reasons:
                continue

            items.append(
                {
                    "user_id": str(user.id),
                    "email": user.email,
                    "created_at": user.created_at,
                    "rate_limit_hits_24h": rate_hits,
                    "shared_signup_ip_accounts_7d": shared_signup_accounts,
                    "reward_valid_7d": counts["valid"],
                    "reward_invalid_7d": counts["invalid"],
                    "reward_invalid_ratio_7d": invalid_ratio,
                    "reward_invalid_streak": invalid_streak,
                    "reward_locked_until": locked_until,
                    "reasons": reasons,
                }
            )

        def sort_key(item: dict[str, object]) -> tuple[int, int, int]:
            reasons = item.get("reasons")
            rate_hits = item.get("rate_limit_hits_24h")
            reward_invalid = item.get("reward_invalid_7d")
            return (
                len(reasons) if isinstance(reasons, list) else 0,
                rate_hits if isinstance(rate_hits, int) else 0,
                reward_invalid if isinstance(reward_invalid, int) else 0,
            )

        items.sort(key=sort_key, reverse=True)
        return items[:limit]

    async def delete_blocked_recordings(
        self,
        *,
        block_id: str,
        principal: AuthPrincipal,
        reason: str,
    ) -> tuple[AdminCreatorBlock, list[str], list[str]]:
        try:
            parsed = uuid.UUID(block_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Creator block not found", status_code=404
            ) from exc
        block = await self.session.get(AdminCreatorBlock, parsed)
        if block is None or block.unblocked_at is not None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Active creator block not found", status_code=404
            )

        recordings = await self._matching_recordings(
            block.source_type,
            block.source_value,
        )
        recording_service = AdminRecordingService(self.session, self.settings)
        deleted: list[str] = []
        pending: list[str] = []
        for recording in recordings:
            status = RecordingStatus(recording.status)
            if status in TERMINAL_RECORDING_STATUSES:
                await recording_service.delete_recording(str(recording.id))
                deleted.append(str(recording.id))
                continue
            if status is RecordingStatus.WAITING_FOR_CLOUD_SLOT:
                await recording_service.stop_recording(str(recording.id))
                await recording_service.delete_recording(str(recording.id))
                deleted.append(str(recording.id))
                continue
            if status in ACTIVE_RECORDING_STATUSES:
                await recording_service.stop_recording(str(recording.id))
                pending.append(str(recording.id))

        if block.complaint_id is not None:
            self.session.add(
                AdminComplaintEvent(
                    complaint_id=block.complaint_id,
                    actor_user_id=principal.user_id,
                    action="blocked_recordings_delete_requested",
                    note=reason,
                    metadata_json={
                        "block_id": str(block.id),
                        "deleted_recording_ids": deleted,
                        "pending_stop_recording_ids": pending,
                    },
                )
            )
        await self.session.flush()
        return block, deleted, pending

    async def unblock_creator(
        self,
        *,
        block_id: str,
        principal: AuthPrincipal,
        reason: str,
    ) -> AdminCreatorBlock:
        try:
            parsed = uuid.UUID(block_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Creator block not found", status_code=404
            ) from exc
        block = await self.session.get(AdminCreatorBlock, parsed)
        if block is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Creator block not found", status_code=404
            )
        if block.unblocked_at is not None:
            raise ApplicationError(
                "VALIDATION_ERROR", "Creator block is already inactive", status_code=409
            )
        block.unblocked_at = utcnow()
        block.unblocked_by_user_id = principal.user_id
        block.unblock_reason = reason

        watches = await self._matching_watches(block.source_type, block.source_value)
        for watch in watches:
            if watch.status == WatchStatus.PAUSED.value and watch.last_error == "creator_blocked":
                watch.status = WatchStatus.ACTIVE.value
                watch.next_check_at = utcnow()
                watch.last_error = None

        if block.complaint_id is not None:
            self.session.add(
                AdminComplaintEvent(
                    complaint_id=block.complaint_id,
                    actor_user_id=principal.user_id,
                    action="creator_unblocked",
                    note=reason,
                    metadata_json={
                        "source_type": block.source_type,
                        "source_value": block.source_value,
                    },
                )
            )
        await self.session.flush()
        return block
