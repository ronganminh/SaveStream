from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import AuditLog


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _encode_cursor(row: AuditLog) -> str:
    payload = json.dumps(
        {"created_at": aware(row.created_at).isoformat(), "id": str(row.id)},
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


@dataclass(frozen=True, slots=True)
class AuditContext:
    request_id: str | None = None
    ip_address: str | None = None
    user_agent: str | None = None


@dataclass(frozen=True, slots=True)
class AuditPage:
    items: list[AuditLog]
    next_cursor: str | None
    has_more: bool


class AuditService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def record(
        self,
        *,
        actor_user_id: uuid.UUID | None,
        action: str,
        resource_type: str | None,
        resource_id: str | None,
        context: AuditContext,
        details: dict[str, Any] | None = None,
        actor_role: str | None = None,
        reason: str | None = None,
        before_state: dict[str, Any] | None = None,
        after_state: dict[str, Any] | None = None,
    ) -> AuditLog:
        row = AuditLog(
            actor_user_id=actor_user_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            request_id=context.request_id,
            ip_address=context.ip_address,
            user_agent=context.user_agent,
            actor_role=actor_role,
            reason=reason,
            before_state=before_state,
            after_state=after_state,
            details=details or {},
        )
        self.session.add(row)
        await self.session.flush()
        return row

    async def list(
        self,
        *,
        limit: int,
        cursor: str | None,
        actor_user_id: uuid.UUID | None = None,
        resource_type: str | None = None,
        action: str | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
    ) -> AuditPage:
        statement = select(AuditLog)
        if actor_user_id is not None:
            statement = statement.where(AuditLog.actor_user_id == actor_user_id)
        if resource_type is not None:
            statement = statement.where(AuditLog.resource_type == resource_type)
        if action is not None:
            statement = statement.where(AuditLog.action == action)
        if created_from is not None:
            statement = statement.where(AuditLog.created_at >= created_from)
        if created_to is not None:
            statement = statement.where(AuditLog.created_at <= created_to)
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    AuditLog.created_at < created_at,
                    and_(AuditLog.created_at == created_at, AuditLog.id < row_id),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        AuditLog.created_at.desc(),
                        AuditLog.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        return AuditPage(
            items=items,
            next_cursor=_encode_cursor(items[-1]) if has_more and items else None,
            has_more=has_more,
        )
