from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Generic, TypeVar

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application.recordings.service import RecordingService
from app.domain.billing.state import PaymentStatus
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import RecordingStatus
from app.infrastructure.db.billing_models import PaymentOrder
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording
from app.settings import AppSettings

T = TypeVar("T")


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    payload = json.dumps(
        {"created_at": _aware(created_at).isoformat(), "id": str(row_id)},
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
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


@dataclass(frozen=True, slots=True)
class AdminPage(Generic[T]):
    items: list[T]
    next_cursor: str | None
    has_more: bool


class AdminService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings

    async def list_users(
        self,
        *,
        limit: int,
        cursor: str | None,
        role: str | None,
        is_active: bool | None,
    ) -> AdminPage[User]:
        statement = select(User)
        if role is not None:
            if role not in {"user", "admin"}:
                raise ApplicationError("VALIDATION_ERROR", "Invalid role", status_code=400)
            statement = statement.where(User.role == role)
        if is_active is not None:
            statement = statement.where(User.is_active.is_(is_active))
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    User.created_at < created_at,
                    and_(User.created_at == created_at, User.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(User.created_at.desc(), User.id.desc()).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AdminPage(
            items,
            _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None,
            has_more,
        )

    async def get_user(self, user_id: str) -> User:
        try:
            parsed = uuid.UUID(user_id)
        except ValueError as exc:
            raise self._user_not_found() from exc
        user = await self.session.get(User, parsed)
        if user is None:
            raise self._user_not_found()
        return user

    async def update_user(
        self,
        *,
        actor_user_id: uuid.UUID,
        user_id: str,
        role: str | None,
        is_active: bool | None,
    ) -> User:
        user = await self.get_user(user_id)
        if user.id == actor_user_id and (role == "user" or is_active is False):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Admin cannot demote or deactivate the current session owner",
                status_code=409,
            )
        if role is not None:
            if role not in {"user", "admin"}:
                raise ApplicationError("VALIDATION_ERROR", "Invalid role", status_code=400)
            user.role = role
        if is_active is not None:
            user.is_active = is_active
        await self.session.flush()
        return user

    async def list_recordings(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None,
        status: str | None,
    ) -> AdminPage[Recording]:
        statement = select(Recording).where(Recording.deleted_at.is_(None))
        if user_id is not None:
            statement = statement.where(Recording.user_id == user_id)
        if status is not None:
            try:
                RecordingStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid recording status", status_code=400
                ) from exc
            statement = statement.where(Recording.status == status)
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    Recording.created_at < created_at,
                    and_(Recording.created_at == created_at, Recording.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        Recording.created_at.desc(), Recording.id.desc()
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AdminPage(
            items,
            _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None,
            has_more,
        )

    async def get_recording(self, recording_id: str) -> Recording:
        try:
            parsed = uuid.UUID(recording_id)
        except ValueError as exc:
            raise self._recording_not_found() from exc
        recording = await self.session.scalar(
            select(Recording).where(
                Recording.id == parsed,
                Recording.deleted_at.is_(None),
            )
        )
        if recording is None:
            raise self._recording_not_found()
        return recording

    async def retry_recording(
        self,
        *,
        recording_id: str,
        idempotency_key: str,
    ) -> tuple[Recording, Recording]:
        original = await self.get_recording(recording_id)
        if RecordingStatus(original.status) is not RecordingStatus.FAILED:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Only failed recordings can be retried",
                status_code=409,
            )
        retry = await RecordingService(self.session, self.settings).create_for_user(
            original.user_id,
            CreateRecordingRequest(
                source=Source.model_validate(
                    {"type": original.source_type, "value": original.source_value}
                ),
                max_duration_seconds=original.max_duration_seconds,
                quality=original.quality,
                container=original.container,
            ),
            idempotency_key=idempotency_key,
        )
        return original, retry

    async def list_payments(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None,
        status: str | None,
    ) -> AdminPage[PaymentOrder]:
        statement = select(PaymentOrder)
        if user_id is not None:
            statement = statement.where(PaymentOrder.user_id == user_id)
        if status is not None:
            try:
                PaymentStatus(status)
            except ValueError as exc:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid payment status", status_code=400
                ) from exc
            statement = statement.where(PaymentOrder.status == status)
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    PaymentOrder.created_at < created_at,
                    and_(PaymentOrder.created_at == created_at, PaymentOrder.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        PaymentOrder.created_at.desc(), PaymentOrder.id.desc()
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AdminPage(
            items,
            _encode_cursor(items[-1].created_at, items[-1].id) if has_more and items else None,
            has_more,
        )

    @staticmethod
    def _user_not_found() -> ApplicationError:
        return ApplicationError("RESOURCE_NOT_FOUND", "User not found", status_code=404)

    @staticmethod
    def _recording_not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND", "Recording not found", status_code=404
        )
