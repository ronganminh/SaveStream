from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.admin.service import AdminService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import AdminBulkGrant, AdminBulkGrantDelivery
from app.infrastructure.db.models import User
from app.infrastructure.queue.outbox import OutboxWriter
from app.settings import AppSettings


def aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def _parse_uuid(value: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise ApplicationError(
            "RESOURCE_NOT_FOUND", "Bulk grant not found", status_code=404
        ) from exc


def _encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    raw = json.dumps(
        {"created_at": aware(created_at).isoformat(), "id": str(row_id)},
        separators=(",", ":"),
    ).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def _decode_cursor(value: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = value + "=" * (-len(value) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode())
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


class AdminBulkGrantService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings
        self.outbox = OutboxWriter()

    async def matching_user_ids(self, filters: dict[str, object]) -> list[uuid.UUID]:
        ids: list[uuid.UUID] = []
        cursor: str | None = None
        service = AdminService(self.session, self.settings)

        query_value = filters.get("query")
        plan_value = filters.get("plan")
        status_value = filters.get("account_status")
        verified_value = filters.get("email_verified")
        provider_value = filters.get("purchase_provider")
        query_filter = query_value if isinstance(query_value, str) else None
        plan_filter = plan_value if isinstance(plan_value, str) else None
        status_filter = status_value if isinstance(status_value, str) else None
        verified_filter = verified_value if isinstance(verified_value, bool) else None
        provider_filter = provider_value if isinstance(provider_value, str) else None
        created_from = (
            datetime.fromisoformat(str(filters["created_from"]))
            if filters.get("created_from")
            else None
        )
        created_to = (
            datetime.fromisoformat(str(filters["created_to"]))
            if filters.get("created_to")
            else None
        )

        while True:
            page = await service.list_users(
                limit=100,
                cursor=cursor,
                role="user",
                is_active=None,
                query=query_filter,
                plan=plan_filter,
                account_status=status_filter,
                email_verified=verified_filter,
                created_from=created_from,
                created_to=created_to,
                purchase_provider=provider_filter,
                sort_by="created_at",
                sort_order="asc",
            )
            ids.extend(user.id for user in page.items)
            if not page.has_more or not page.next_cursor:
                break
            cursor = page.next_cursor
        return ids

    async def preview(
        self, *, credits: int, filters: dict[str, object]
    ) -> dict[str, int]:
        user_ids = await self.matching_user_ids(filters)
        count = len(user_ids)
        return {
            "audience_count": count,
            "credits_per_user": credits,
            "total_credits": count * credits,
        }

    async def create(
        self,
        *,
        actor_user_id: uuid.UUID,
        credits: int,
        counts_as_purchase: bool,
        reason: str,
        filters: dict[str, object],
    ) -> AdminBulkGrant:
        preview = await self.preview(credits=credits, filters=filters)
        grant = AdminBulkGrant(
            actor_user_id=actor_user_id,
            credits=credits,
            counts_as_purchase=counts_as_purchase,
            reason=reason,
            filters=filters,
            status="queued",
            audience_count=preview["audience_count"],
            total_credits=preview["total_credits"],
        )
        self.session.add(grant)
        await self.session.flush()
        await self.outbox.enqueue(
            self.session,
            topic="admin.bulk_grant",
            payload={"bulk_grant_id": str(grant.id)},
            aggregate_type="admin_bulk_grant",
            aggregate_id=str(grant.id),
        )
        return grant

    async def get(self, grant_id: str) -> AdminBulkGrant:
        row = await self.session.get(AdminBulkGrant, _parse_uuid(grant_id))
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Bulk grant not found", status_code=404
            )
        return row

    @staticmethod
    def payload(row: AdminBulkGrant) -> dict[str, object]:
        return {
            "id": str(row.id),
            "credits": row.credits,
            "counts_as_purchase": row.counts_as_purchase,
            "reason": row.reason,
            "filters": row.filters,
            "status": row.status,
            "audience_count": row.audience_count,
            "total_credits": row.total_credits,
            "delivered_count": row.delivered_count,
            "failed_count": row.failed_count,
            "error": row.error,
            "created_at": row.created_at,
            "started_at": row.started_at,
            "completed_at": row.completed_at,
        }

    async def deliveries(
        self,
        grant_id: str,
        *,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        grant = await self.get(grant_id)
        statement = (
            select(AdminBulkGrantDelivery, User.email)
            .join(User, User.id == AdminBulkGrantDelivery.user_id)
            .where(AdminBulkGrantDelivery.bulk_grant_id == grant.id)
        )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    AdminBulkGrantDelivery.created_at < created_at,
                    and_(
                        AdminBulkGrantDelivery.created_at == created_at,
                        AdminBulkGrantDelivery.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.execute(
                    statement.order_by(
                        AdminBulkGrantDelivery.created_at.desc(),
                        AdminBulkGrantDelivery.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        selected = rows[:limit]
        items = [
            {
                "id": str(row[0].id),
                "user_id": str(row[0].user_id),
                "user_email": row[1],
                "ledger_entry_id": (
                    str(row[0].ledger_entry_id) if row[0].ledger_entry_id else None
                ),
                "status": row[0].status,
                "error": row[0].error,
                "created_at": row[0].created_at,
                "updated_at": row[0].updated_at,
            }
            for row in selected
        ]
        next_cursor = (
            _encode_cursor(selected[-1][0].created_at, selected[-1][0].id)
            if has_more and selected
            else None
        )
        return items, next_cursor, has_more
