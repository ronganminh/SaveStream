from __future__ import annotations

import base64
import hashlib
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import Source
from app.api.schemas.watches import CreateWatchRequest, UpdateWatchRequest
from app.application.credits.service import CreditService
from app.application.creator_safety import ensure_creator_not_blocked
from app.application.entitlements.service import EntitlementService, EntitlementSnapshot
from app.application.quotas.service import QuotaService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.watches.state import WatchStatus, can_resume, validate_user_status
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.watch_models import Watch
from app.settings import AppSettings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def normalize_source(source: Source) -> str:
    value = source.value.strip()
    if source.type == "username":
        value = value.lstrip("@").casefold()
    return value


def watch_dedupe_key(user_id: uuid.UUID, source: Source) -> str:
    raw = f"{user_id}:{source.type}:{normalize_source(source)}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def encode_cursor(watch: Watch) -> str:
    payload = json.dumps(
        {"created_at": aware(watch.created_at).isoformat(), "id": str(watch.id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


@dataclass(frozen=True, slots=True)
class WatchPage:
    items: list[Watch]
    next_cursor: str | None
    has_more: bool


class WatchService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def entitlement_for(self, user_id: uuid.UUID) -> EntitlementSnapshot:
        return await EntitlementService(self.session, self.settings).get(user_id)

    async def waiting_room_ids(self, user_id: uuid.UUID) -> set[str]:
        rows = await self.session.scalars(
            select(Recording.source_value).where(
                Recording.user_id == user_id,
                Recording.deleted_at.is_(None),
                Recording.status == "waiting_for_cloud_slot",
                Recording.source_type == "room_id",
            )
        )
        return set(rows.all())

    async def create(
        self,
        principal: AuthPrincipal,
        payload: CreateWatchRequest,
    ) -> Watch:
        source = Source(
            type=payload.source.type,
            value=normalize_source(payload.source),
        )
        await ensure_creator_not_blocked(
            self.session,
            source_type=source.type,
            source_value=source.value,
        )
        key = watch_dedupe_key(principal.user_id, source)
        existing = await self.session.scalar(
            select(Watch).where(
                Watch.active_dedupe_key == key,
                Watch.deleted_at.is_(None),
            )
        )
        if existing is not None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "A Watch already exists for this source",
                status_code=409,
                details={"watch_id": str(existing.id)},
            )

        entitlement = await self.entitlement_for(principal.user_id)
        if payload.auto_record and not entitlement.is_pro:
            raise ApplicationError(
                "PLAN_REQUIRED",
                "Automatic cloud recording requires purchased cloud minutes",
                status_code=403,
                retryable=False,
                details={"plan": entitlement.plan},
            )

        await QuotaService(self.session, self.settings).check_watch_create(
            principal.user_id
        )

        watch = Watch(
            user_id=principal.user_id,
            source_type=source.type,
            source_value=source.value,
            active_dedupe_key=key,
            resolved_username=source.value if source.type == "username" else None,
            status=WatchStatus.ACTIVE.value,
            live_status="unknown",
            auto_record=payload.auto_record,
            notify_on_live=payload.notify_on_live,
            next_check_at=utcnow(),
        )
        self.session.add(watch)
        try:
            await self.session.commit()
        except IntegrityError as exc:
            await self.session.rollback()
            raise ApplicationError(
                "VALIDATION_ERROR",
                "A Watch already exists for this source",
                status_code=409,
            ) from exc
        await self.session.refresh(watch)
        return watch

    async def get(self, principal: AuthPrincipal, watch_id: str) -> Watch:
        try:
            parsed = uuid.UUID(watch_id)
        except ValueError as exc:
            raise self._not_found() from exc
        watch = await self.session.scalar(
            select(Watch).where(
                Watch.id == parsed,
                Watch.user_id == principal.user_id,
                Watch.deleted_at.is_(None),
            )
        )
        if watch is None:
            raise self._not_found()
        return watch

    async def list(
        self,
        principal: AuthPrincipal,
        *,
        limit: int,
        cursor: str | None,
        status: str | None,
    ) -> WatchPage:
        statement = select(Watch).where(
            Watch.user_id == principal.user_id,
            Watch.deleted_at.is_(None),
        )
        if status is not None:
            try:
                WatchStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid Watch status", status_code=400
                ) from exc
            statement = statement.where(Watch.status == status)
        if cursor:
            created_at, watch_id = decode_cursor(cursor)
            statement = statement.where(
                or_(
                    Watch.created_at < created_at,
                    and_(
                        Watch.created_at == created_at,
                        Watch.id < watch_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(Watch.created_at.desc(), Watch.id.desc()).limit(
                        limit + 1
                    )
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = encode_cursor(items[-1]) if has_more and items else None
        return WatchPage(items=items, next_cursor=next_cursor, has_more=has_more)

    async def update(
        self,
        principal: AuthPrincipal,
        watch_id: str,
        payload: UpdateWatchRequest,
    ) -> Watch:
        watch = await self.get(principal, watch_id)
        if payload.auto_record is not None:
            if payload.auto_record:
                entitlement = await self.entitlement_for(principal.user_id)
                if not entitlement.is_pro:
                    raise ApplicationError(
                        "PLAN_REQUIRED",
                        "Automatic cloud recording requires purchased cloud minutes",
                        status_code=403,
                        retryable=False,
                        details={"plan": entitlement.plan},
                    )
            watch.auto_record = payload.auto_record
        if payload.notify_on_live is not None:
            watch.notify_on_live = payload.notify_on_live
        if payload.status is not None:
            status = validate_user_status(payload.status)
            watch.status = status.value
            watch.scheduler_lease_id = None
            watch.scheduler_lease_expires_at = None
            if status is WatchStatus.ACTIVE:
                await ensure_creator_not_blocked(
                    self.session,
                    source_type=watch.source_type,
                    source_value=watch.resolved_username or watch.source_value,
                )
                watch.failure_count = 0
                watch.last_error = None
                watch.next_check_at = utcnow()
            else:
                watch.next_check_at = None
        await self.session.commit()
        await self.session.refresh(watch)
        return watch

    async def delete(self, principal: AuthPrincipal, watch_id: str) -> None:
        watch = await self.get(principal, watch_id)
        watch.deleted_at = utcnow()
        watch.status = WatchStatus.DISABLED.value
        watch.next_check_at = None
        watch.active_dedupe_key = None
        watch.scheduler_lease_id = None
        watch.scheduler_lease_expires_at = None
        await self.session.commit()

    async def resume(self, principal: AuthPrincipal, watch_id: str) -> Watch:
        watch = await self.get(principal, watch_id)
        status = WatchStatus(watch.status)
        if not can_resume(status):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Watch cannot be resumed in its current state",
                status_code=409,
            )
        await ensure_creator_not_blocked(
            self.session,
            source_type=watch.source_type,
            source_value=watch.resolved_username or watch.source_value,
        )
        entitlement = await self.entitlement_for(principal.user_id)
        if watch.auto_record and entitlement.is_pro:
            affordable, required, available = await CreditService(
                self.session
            ).can_afford(
                user_id=principal.user_id,
                max_duration_seconds=self.settings.recording_max_duration_seconds,
            )
            if not affordable:
                watch.status = WatchStatus.PAUSED_INSUFFICIENT_CREDIT.value
                watch.next_check_at = None
                await self.session.commit()
                raise ApplicationError(
                    "INSUFFICIENT_CREDITS",
                    "Available credit is insufficient",
                    status_code=402,
                    retryable=False,
                    details={"required": required, "available": available},
                )

        watch.status = WatchStatus.ACTIVE.value
        watch.failure_count = 0
        watch.last_error = None
        watch.next_check_at = utcnow()
        watch.scheduler_lease_id = None
        watch.scheduler_lease_expires_at = None
        await self.session.commit()
        await self.session.refresh(watch)
        return watch

    @staticmethod
    def _not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND", "Watch not found", status_code=404
        )
