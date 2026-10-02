from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from sqlalchemy import exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.billing_models import PaymentOrder
from app.settings import AppSettings

# Accounts that have bought credits keep recordings longer than trial-only accounts.
PAID_ORDER_STATUSES = ("paid", "partially_refunded")


def paid_customer_clause():
    """SQL predicate on a user id column: the user has at least one paid order."""
    return select(PaymentOrder.user_id).where(PaymentOrder.status.in_(PAID_ORDER_STATUSES))


async def has_paid_purchase(session: AsyncSession, user_id: uuid.UUID) -> bool:
    return bool(
        await session.scalar(
            select(
                exists().where(
                    PaymentOrder.user_id == user_id,
                    PaymentOrder.status.in_(PAID_ORDER_STATUSES),
                )
            )
        )
    )


def retention_days(settings: AppSettings, *, paid: bool) -> int:
    """Days a finished recording is kept; 0 keeps it until the user deletes it."""
    if paid:
        return settings.recording_retention_days
    return settings.recording_retention_days_free or settings.recording_retention_days


def expires_at(created_at: datetime, days: int) -> datetime | None:
    return created_at + timedelta(days=days) if days > 0 else None
