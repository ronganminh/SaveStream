from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.infrastructure.db.admin_models import (
    AdminComplaintCase,
    AdminDailyMetric,
    AdminSupportReport,
)
from app.infrastructure.db.billing_models import PaymentOrder
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.models import AuthSession, User
from app.infrastructure.db.recording_models import Recording

PAID_ORDER_STATUSES = ("paid", "partially_refunded", "refunded")
PRO_ORDER_STATUSES = ("paid", "partially_refunded")
STORE_FEE_ESTIMATE_BPS = 3000
GLOBAL_RECORDING_STREAM_LIMIT = 6
PENDING_STUCK_AFTER = timedelta(minutes=15)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _bounds(day: date) -> tuple[datetime, datetime]:
    start = datetime.combine(day, time.min, tzinfo=timezone.utc)
    return start, start + timedelta(days=1)


def _store_fee(amount_minor: int) -> int:
    return (amount_minor * STORE_FEE_ESTIMATE_BPS + 5000) // 10000


class AdminOverviewService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def series(self, *, days: int = 30) -> list[AdminDailyMetric]:
        rows = list(
            (
                await self.session.scalars(
                    select(AdminDailyMetric)
                    .order_by(AdminDailyMetric.day.desc())
                    .limit(days)
                )
            ).all()
        )
        rows.reverse()
        return rows

    async def month_totals(self, *, day: date | None = None) -> dict[str, int]:
        target = day or utcnow().date()
        month_start = target.replace(day=1)
        rows = list(
            (
                await self.session.scalars(
                    select(AdminDailyMetric).where(
                        AdminDailyMetric.day >= month_start,
                        AdminDailyMetric.day <= target,
                    )
                )
            ).all()
        )
        return {
            "web": sum(row.revenue_web_usd_minor for row in rows),
            "app_store": sum(row.revenue_app_store_usd_minor for row in rows),
            "google_play": sum(row.revenue_google_play_usd_minor for row in rows),
            "store_fee": sum(
                row.estimated_store_fee_app_store_usd_minor
                + row.estimated_store_fee_google_play_usd_minor
                for row in rows
            ),
        }

    async def daily_range(
        self,
        *,
        start_day: date,
        end_day: date,
        max_days: int = 366,
    ) -> list[AdminDailyMetric]:
        if end_day < start_day:
            return []
        if (end_day - start_day).days + 1 > max_days:
            start_day = end_day - timedelta(days=max_days - 1)
        return list(
            (
                await self.session.scalars(
                    select(AdminDailyMetric)
                    .where(
                        AdminDailyMetric.day >= start_day,
                        AdminDailyMetric.day <= end_day,
                    )
                    .order_by(AdminDailyMetric.day.asc())
                )
            ).all()
        )

    async def compute_daily(self, *, day: date | None = None) -> AdminDailyMetric:
        now = utcnow()
        target = day or now.date()
        day_start, day_end = _bounds(target)
        week_start = day_end - timedelta(days=7)
        month_active_start = day_end - timedelta(days=30)
        activity_end = min(day_end, now)

        new_users = int(
            await self.session.scalar(
                select(func.count())
                .select_from(User)
                .where(
                    User.role == "user",
                    User.created_at >= day_start,
                    User.created_at < day_end,
                )
            )
            or 0
        )

        async def active_users(since: datetime) -> int:
            return int(
                await self.session.scalar(
                    select(func.count(func.distinct(AuthSession.user_id)))
                    .select_from(AuthSession)
                    .join(User, User.id == AuthSession.user_id)
                    .where(
                        User.role == "user",
                        AuthSession.last_seen_at >= since,
                        AuthSession.last_seen_at < activity_end,
                    )
                )
                or 0
            )

        active_daily = await active_users(day_start)
        active_weekly = await active_users(week_start)
        active_monthly = await active_users(month_active_start)

        user_total = int(
            await self.session.scalar(
                select(func.count()).select_from(User).where(User.role == "user")
            )
            or 0
        )
        positive_credit_users = set(
            (
                await self.session.scalars(
                    select(CreditAccount.user_id)
                    .join(User, User.id == CreditAccount.user_id)
                    .where(
                        User.role == "user",
                        CreditAccount.posted_balance > 0,
                    )
                )
            ).all()
        )
        paid_users = set(
            (
                await self.session.scalars(
                    select(PaymentOrder.user_id)
                    .where(PaymentOrder.status.in_(PRO_ORDER_STATUSES))
                    .distinct()
                )
            ).all()
        )
        purchase_grants = list(
            (
                await self.session.scalars(
                    select(CreditLedgerEntry).where(
                        CreditLedgerEntry.amount > 0,
                    )
                )
            ).all()
        )
        grant_purchase_users = {
            entry.user_id
            for entry in purchase_grants
            if bool(entry.details.get("counts_as_purchase", False))
        }
        pro_users = len(
            positive_credit_users.intersection(paid_users | grant_purchase_users)
        )
        free_users = max(user_total - pro_users, 0)

        first_purchase: dict[object, datetime] = {}
        paid_first_rows = (
            await self.session.execute(
                select(
                    PaymentOrder.user_id,
                    func.min(PaymentOrder.paid_at),
                )
                .where(
                    PaymentOrder.status.in_(PAID_ORDER_STATUSES),
                    PaymentOrder.paid_at.is_not(None),
                )
                .group_by(PaymentOrder.user_id)
            )
        ).all()
        for user_id, purchased_at in paid_first_rows:
            if purchased_at is not None:
                first_purchase[user_id] = purchased_at

        for entry in purchase_grants:
            if not bool(entry.details.get("counts_as_purchase", False)):
                continue
            previous = first_purchase.get(entry.user_id)
            if previous is None or entry.created_at < previous:
                first_purchase[entry.user_id] = entry.created_at

        free_to_pro_weekly = sum(
            1
            for purchased_at in first_purchase.values()
            if week_start <= purchased_at.replace(
                tzinfo=purchased_at.tzinfo or timezone.utc
            ) < day_end
        )

        revenue = {"web": 0, "app_store": 0, "google_play": 0}
        payment_rows = (
            await self.session.execute(
                select(
                    PaymentOrder.provider,
                    PaymentOrder.amount_minor,
                    PaymentOrder.currency,
                ).where(
                    PaymentOrder.status.in_(PAID_ORDER_STATUSES),
                    PaymentOrder.paid_at >= day_start,
                    PaymentOrder.paid_at < day_end,
                )
            )
        ).all()
        for provider, amount_minor, currency in payment_rows:
            if currency != "USD":
                continue
            channel = (
                provider
                if provider in {"app_store", "google_play"}
                else "web"
            )
            revenue[channel] += int(amount_minor)

        recording_running = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.status == "recording",
                )
            )
            or 0
        )
        recording_waiting = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.status == "waiting_for_cloud_slot",
                )
            )
            or 0
        )
        recent_start = min(now, day_end) - timedelta(hours=24)
        recording_total_24h = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.created_at >= recent_start,
                    Recording.created_at < activity_end,
                )
            )
            or 0
        )
        recording_errors_24h = int(
            await self.session.scalar(
                select(func.count())
                .select_from(Recording)
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.status == "failed",
                    Recording.updated_at >= recent_start,
                    Recording.updated_at < activity_end,
                )
            )
            or 0
        )

        status_rows = (
            await self.session.execute(
                select(Recording.status, func.count())
                .where(
                    Recording.deleted_at.is_(None),
                    Recording.created_at >= day_start,
                    Recording.created_at < day_end,
                )
                .group_by(Recording.status)
            )
        ).all()
        recording_status_counts = {
            str(status): int(count)
            for status, count in status_rows
        }

        cloud_minutes_used = int(
            -(
                await self.session.scalar(
                    select(func.coalesce(func.sum(CreditLedgerEntry.amount), 0)).where(
                        CreditLedgerEntry.entry_type == "charge",
                        CreditLedgerEntry.reference_type == "recording",
                        CreditLedgerEntry.created_at >= day_start,
                        CreditLedgerEntry.created_at < day_end,
                    )
                )
                or 0
            )
        )

        pending_old = int(
            await self.session.scalar(
                select(func.count())
                .select_from(PaymentOrder)
                .where(
                    PaymentOrder.status == "pending",
                    PaymentOrder.updated_at <= now - PENDING_STUCK_AFTER,
                )
            )
            or 0
        )
        paid_order_ids = {
            str(value)
            for value in (
                await self.session.scalars(
                    select(PaymentOrder.id).where(
                        PaymentOrder.status.in_(PRO_ORDER_STATUSES)
                    )
                )
            ).all()
        }
        granted_order_ids = set(
            (
                await self.session.scalars(
                    select(CreditLedgerEntry.reference_id).where(
                        CreditLedgerEntry.reference_type == "payment_order",
                        CreditLedgerEntry.amount > 0,
                        CreditLedgerEntry.reference_id.is_not(None),
                    )
                )
            ).all()
        )
        stuck_orders = pending_old + len(paid_order_ids - granted_order_ids)

        open_complaints = int(
            await self.session.scalar(
                select(func.count())
                .select_from(AdminComplaintCase)
                .where(AdminComplaintCase.status.in_(("new", "reviewing")))
            )
            or 0
        )

        row = await self.session.get(AdminDailyMetric, target)
        values = {
            "new_users": new_users,
            "active_users_daily": active_daily,
            "active_users_weekly": active_weekly,
            "active_users_monthly": active_monthly,
            "free_users": free_users,
            "pro_users": pro_users,
            "free_to_pro_weekly": free_to_pro_weekly,
            "revenue_web_usd_minor": revenue["web"],
            "revenue_app_store_usd_minor": revenue["app_store"],
            "revenue_google_play_usd_minor": revenue["google_play"],
            "estimated_store_fee_app_store_usd_minor": _store_fee(
                revenue["app_store"]
            ),
            "estimated_store_fee_google_play_usd_minor": _store_fee(
                revenue["google_play"]
            ),
            "recording_running": recording_running,
            "recording_waiting": recording_waiting,
            "recording_errors_24h": recording_errors_24h,
            "recording_total_24h": recording_total_24h,
            "cloud_minutes_used": cloud_minutes_used,
            "recording_status_counts": recording_status_counts,
            "recording_capacity_limit": GLOBAL_RECORDING_STREAM_LIMIT,
            "stuck_orders": stuck_orders,
            "open_complaints": open_complaints,
            "computed_at": now,
        }
        if row is None:
            row = AdminDailyMetric(day=target, **values)
            self.session.add(row)
        else:
            for key, value in values.items():
                setattr(row, key, value)
        await self.session.flush()
        return row

    async def purge_expired_support_reports(self) -> int:
        result = await self.session.execute(
            delete(AdminSupportReport).where(
                AdminSupportReport.expires_at <= utcnow()
            )
        )
        return int(result.rowcount or 0)
