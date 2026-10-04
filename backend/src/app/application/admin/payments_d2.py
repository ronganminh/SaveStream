from __future__ import annotations

import base64
import json
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.billing.credits import BillingCreditService
from app.application.billing.service import PaymentEventProcessor
from app.application.credits.service import CreditService
from app.application.notifications.service import ensure_purchase_completed_notification
from app.domain.billing.state import PaymentStatus
from app.domain.common.errors import ApplicationError
from app.domain.recordings.state import TERMINAL_RECORDING_STATUSES
from app.infrastructure.db.billing_models import (
    CreditPackage,
    PaymentEvent,
    PaymentOrder,
    Refund,
)
from app.infrastructure.db.credit_models import CreditLedgerEntry, CreditReservation
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.payments.base import PaymentProvider, ProviderEvent


STORE_PROVIDERS = frozenset({"app_store", "google_play"})
STORE_FEE_ESTIMATE_BPS = 3000
PENDING_STUCK_AFTER = timedelta(minutes=15)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def _encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    payload = json.dumps(
        {"created_at": aware(created_at).isoformat(), "id": str(row_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


def _parse_uuid(value: str, resource: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise ApplicationError(
            "RESOURCE_NOT_FOUND", f"{resource} not found", status_code=404
        ) from exc


def _channel(provider: str | None) -> str:
    if provider == "app_store":
        return "app_store"
    if provider == "google_play":
        return "google_play"
    return "web"


def _estimated_store_fee(amount_minor: int, provider: str | None) -> int | None:
    if provider not in STORE_PROVIDERS:
        return None
    return (amount_minor * STORE_FEE_ESTIMATE_BPS + 5000) // 10000


def _ledger_category(entry: CreditLedgerEntry) -> str:
    if entry.entry_type == "charge":
        return "spend"
    if entry.entry_type == "refund":
        return "refund"
    if entry.reference_type == "payment_order" and entry.amount > 0:
        return "purchase"
    if entry.reference_type == "admin_adjustment" and entry.amount > 0:
        return "gift"
    if entry.entry_type == "grant":
        return "gift"
    return "adjustment"


class AdminFinanceService:
    def __init__(self, session: AsyncSession, provider: PaymentProvider) -> None:
        self.session = session
        self.provider = provider

    @staticmethod
    def payment_payload(
        order: PaymentOrder,
        *,
        user_email: str,
        package_code: str,
        package_name: str,
    ) -> dict[str, object]:
        return {
            "id": str(order.id),
            "user_id": str(order.user_id),
            "user_email": user_email,
            "package_id": str(order.package_id),
            "package_code": package_code,
            "package_name": package_name,
            "status": order.status,
            "purchase_channel": _channel(order.provider),
            "provider": order.provider,
            "provider_transaction_id": order.provider_reference,
            "credits": order.credits,
            "amount_minor": order.amount_minor,
            "currency": order.currency,
            "refunded_credits": order.refunded_credits,
            "refunded_amount_minor": order.refunded_amount_minor,
            "gross_usd_minor": order.amount_minor if order.currency == "USD" else None,
            "estimated_store_fee_minor": _estimated_store_fee(
                order.amount_minor, order.provider
            ),
            "estimated_store_fee_rate_bps": (
                STORE_FEE_ESTIMATE_BPS if order.provider in STORE_PROVIDERS else None
            ),
            "refund_mode": (
                "store_managed" if order.provider in STORE_PROVIDERS else "admin_web"
            ),
            "paid_at": order.paid_at,
            "created_at": order.created_at,
            "updated_at": order.updated_at,
        }

    async def list_payments(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None = None,
        status: str | None = None,
        channel: str | None = None,
        package_id: uuid.UUID | None = None,
        query: str | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
        sort_order: str = "desc",
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        statement = (
            select(PaymentOrder, User.email, CreditPackage.code, CreditPackage.name)
            .join(User, User.id == PaymentOrder.user_id)
            .join(CreditPackage, CreditPackage.id == PaymentOrder.package_id)
        )
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
        if channel is not None:
            if channel not in {"web", "app_store", "google_play"}:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid purchase channel", status_code=400
                )
            if channel == "web":
                statement = statement.where(
                    or_(
                        PaymentOrder.provider.is_(None),
                        PaymentOrder.provider.not_in(tuple(STORE_PROVIDERS)),
                    )
                )
            else:
                statement = statement.where(PaymentOrder.provider == channel)
        if package_id is not None:
            statement = statement.where(PaymentOrder.package_id == package_id)
        if created_from is not None:
            statement = statement.where(PaymentOrder.created_at >= created_from)
        if created_to is not None:
            statement = statement.where(PaymentOrder.created_at <= created_to)
        if query and query.strip():
            pattern = f"%{query.strip()}%"
            statement = statement.where(
                or_(
                    User.email.ilike(pattern),
                    CreditPackage.code.ilike(pattern),
                    CreditPackage.name.ilike(pattern),
                    PaymentOrder.provider_reference.ilike(pattern),
                )
            )
        if sort_order not in {"asc", "desc"}:
            raise ApplicationError(
                "VALIDATION_ERROR", "Invalid sort order", status_code=400
            )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            if sort_order == "asc":
                statement = statement.where(
                    or_(
                        PaymentOrder.created_at > created_at,
                        and_(
                            PaymentOrder.created_at == created_at,
                            PaymentOrder.id > row_id,
                        ),
                    )
                )
            else:
                statement = statement.where(
                    or_(
                        PaymentOrder.created_at < created_at,
                        and_(
                            PaymentOrder.created_at == created_at,
                            PaymentOrder.id < row_id,
                        ),
                    )
                )
        ordering = (
            (PaymentOrder.created_at.asc(), PaymentOrder.id.asc())
            if sort_order == "asc"
            else (PaymentOrder.created_at.desc(), PaymentOrder.id.desc())
        )
        rows = list((await self.session.execute(statement.order_by(*ordering).limit(limit + 1))).all())
        has_more = len(rows) > limit
        selected = rows[:limit]
        items = [
            self.payment_payload(
                row[0],
                user_email=row[1],
                package_code=row[2],
                package_name=row[3],
            )
            for row in selected
        ]
        next_cursor = (
            _encode_cursor(selected[-1][0].created_at, selected[-1][0].id)
            if has_more and selected
            else None
        )
        return items, next_cursor, has_more

    async def _payment_row(
        self, payment_order_id: str
    ) -> tuple[PaymentOrder, str, str, str]:
        parsed = _parse_uuid(payment_order_id, "Payment order")
        row = (
            await self.session.execute(
                select(PaymentOrder, User.email, CreditPackage.code, CreditPackage.name)
                .join(User, User.id == PaymentOrder.user_id)
                .join(CreditPackage, CreditPackage.id == PaymentOrder.package_id)
                .where(PaymentOrder.id == parsed)
            )
        ).first()
        if row is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Payment order not found", status_code=404
            )
        return row[0], row[1], row[2], row[3]

    async def payment_detail(self, payment_order_id: str) -> dict[str, object]:
        order, email, package_code, package_name = await self._payment_row(
            payment_order_id
        )
        timeline: list[dict[str, object]] = [
            {"at": order.created_at, "event": "order.created", "status": "created"}
        ]
        if order.paid_at is not None:
            timeline.append(
                {"at": order.paid_at, "event": "payment.paid", "status": "paid"}
            )
        events = list(
            (
                await self.session.scalars(
                    select(PaymentEvent)
                    .where(PaymentEvent.payment_order_id == order.id)
                    .order_by(PaymentEvent.received_at, PaymentEvent.id)
                )
            ).all()
        )
        timeline.extend(
            {
                "at": event.received_at,
                "event": event.event_type,
                "status": None,
                "detail": event.processing_error,
            }
            for event in events
        )
        refunds = list(
            (
                await self.session.scalars(
                    select(Refund)
                    .where(Refund.payment_order_id == order.id)
                    .order_by(Refund.created_at, Refund.id)
                )
            ).all()
        )
        for refund in refunds:
            timeline.append(
                {
                    "at": refund.created_at,
                    "event": "refund.requested",
                    "status": refund.status,
                    "detail": refund.failure_message,
                }
            )
            if refund.succeeded_at is not None:
                timeline.append(
                    {
                        "at": refund.succeeded_at,
                        "event": "refund.succeeded",
                        "status": "succeeded",
                    }
                )
        timeline.sort(key=lambda item: aware(item["at"]))  # type: ignore[arg-type]
        return {
            "order": self.payment_payload(
                order,
                user_email=email,
                package_code=package_code,
                package_name=package_name,
            ),
            "timeline": timeline,
        }

    async def refund_preview(
        self, payment_order_id: str, amount_minor: int
    ) -> dict[str, object]:
        order, _, _, _ = await self._payment_row(payment_order_id)
        if order.provider in STORE_PROVIDERS:
            raise ApplicationError(
                "STORE_REFUND_MANAGED",
                "Store purchases can only be refunded by Apple or Google",
                status_code=409,
            )
        if PaymentStatus(order.status) not in {
            PaymentStatus.PAID,
            PaymentStatus.PARTIALLY_REFUNDED,
        }:
            raise ApplicationError(
                "PAYMENT_FAILED", "Payment order is not refundable", status_code=409
            )
        refunds = list(
            (
                await self.session.scalars(
                    select(Refund).where(
                        Refund.payment_order_id == order.id,
                        Refund.status.in_(["created", "pending", "succeeded"]),
                    )
                )
            ).all()
        )
        already_amount = sum(item.amount_minor for item in refunds)
        already_credits = sum(item.credits for item in refunds)
        remaining_amount = max(order.amount_minor - already_amount, 0)
        remaining_credits = max(order.credits - already_credits, 0)
        if amount_minor <= 0 or amount_minor > remaining_amount:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Refund amount exceeds the remaining refundable amount",
                status_code=409,
            )
        corresponding = (
            remaining_credits
            if amount_minor == remaining_amount
            else (
                remaining_credits * amount_minor + remaining_amount - 1
            )
            // remaining_amount
        )
        balance = await CreditService(self.session).balance(order.user_id)
        deducted = min(corresponding, max(balance.available, 0))
        return {
            "payment_order_id": str(order.id),
            "amount_minor": amount_minor,
            "corresponding_credits": corresponding,
            "deducted_credits": deducted,
            "balance_available": max(balance.available, 0),
            "remaining_refundable_amount_minor": remaining_amount,
            "remaining_refundable_credits": remaining_credits,
        }

    async def stuck_payments(
        self,
        *,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        statement = (
            select(PaymentOrder, User.email, CreditPackage.code, CreditPackage.name)
            .join(User, User.id == PaymentOrder.user_id)
            .join(CreditPackage, CreditPackage.id == PaymentOrder.package_id)
            .where(
                PaymentOrder.status.in_(
                    [
                        PaymentStatus.PENDING.value,
                        PaymentStatus.PAID.value,
                        PaymentStatus.PARTIALLY_REFUNDED.value,
                    ]
                )
            )
        )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    PaymentOrder.created_at < created_at,
                    and_(
                        PaymentOrder.created_at == created_at,
                        PaymentOrder.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.execute(
                    statement.order_by(
                        PaymentOrder.created_at.desc(), PaymentOrder.id.desc()
                    ).limit(limit * 5 + 1)
                )
            ).all()
        )
        order_ids = [str(row[0].id) for row in rows]
        granted = set(
            await self.session.scalars(
                select(CreditLedgerEntry.reference_id).where(
                    CreditLedgerEntry.reference_type == "payment_order",
                    CreditLedgerEntry.amount > 0,
                    CreditLedgerEntry.reference_id.in_(order_ids),
                )
            )
        )
        cutoff = utcnow() - PENDING_STUCK_AFTER
        stuck: list[tuple[object, str]] = []
        for row in rows:
            order = row[0]
            reason: str | None = None
            if (
                order.status == PaymentStatus.PENDING.value
                and aware(order.updated_at) <= cutoff
            ):
                reason = "pending_too_long"
            elif (
                order.status
                in {
                    PaymentStatus.PAID.value,
                    PaymentStatus.PARTIALLY_REFUNDED.value,
                }
                and str(order.id) not in granted
            ):
                reason = "paid_missing_credit"
            if reason is not None:
                stuck.append((row, reason))
        has_more = len(stuck) > limit or len(rows) > limit * 5
        selected = stuck[:limit]
        items = [
            {
                "order": self.payment_payload(
                    item[0][0],
                    user_email=item[0][1],
                    package_code=item[0][2],
                    package_name=item[0][3],
                ),
                "reason": item[1],
            }
            for item in selected
        ]
        next_cursor = (
            _encode_cursor(selected[-1][0][0].created_at, selected[-1][0][0].id)
            if has_more and selected
            else None
        )
        return items, next_cursor, has_more

    async def reconcile_payment(self, payment_order_id: str) -> dict[str, object]:
        order, _, _, _ = await self._payment_row(payment_order_id)
        status = PaymentStatus(order.status)
        if status in {PaymentStatus.PAID, PaymentStatus.PARTIALLY_REFUNDED}:
            grant = await self.session.scalar(
                select(CreditLedgerEntry.id).where(
                    CreditLedgerEntry.reference_type == "payment_order",
                    CreditLedgerEntry.reference_id == str(order.id),
                    CreditLedgerEntry.amount > 0,
                )
            )
            if grant is not None:
                return {
                    "payment_order_id": str(order.id),
                    "action": "no_change",
                    "status": order.status,
                }
            reference = None
            if order.provider in STORE_PROVIDERS and order.provider_reference:
                reference = (
                    f"store:{order.provider}:{order.provider_reference}:grant"
                )
            await BillingCreditService(self.session).grant_purchase(
                user_id=order.user_id,
                payment_order_id=order.id,
                credits=order.credits,
                idempotency_reference=reference,
            )
            await ensure_purchase_completed_notification(self.session, order)
            await self.session.commit()
            return {
                "payment_order_id": str(order.id),
                "action": "credits_repaired",
                "status": order.status,
            }

        if status is not PaymentStatus.PENDING:
            return {
                "payment_order_id": str(order.id),
                "action": "no_change",
                "status": order.status,
            }
        if order.provider in STORE_PROVIDERS:
            raise ApplicationError(
                "STORE_RECONCILE_MANAGED",
                "Store payment state only updates from verified Apple or Google events",
                status_code=409,
            )
        if (
            order.provider != self.provider.name
            or not order.provider_reference
        ):
            raise ApplicationError(
                "RECONCILIATION_UNAVAILABLE",
                "Payment provider reconciliation is unavailable",
                status_code=409,
            )
        provider_state = await self.provider.retrieve_payment(order.provider_reference)
        if provider_state is None or provider_state.status == "pending":
            return {
                "payment_order_id": str(order.id),
                "action": "still_pending",
                "status": order.status,
            }
        event_type = {
            "paid": "payment.paid",
            "failed": "payment.failed",
            "cancelled": "payment.cancelled",
            "expired": "payment.expired",
        }.get(provider_state.status)
        if event_type is None:
            return {
                "payment_order_id": str(order.id),
                "action": "still_pending",
                "status": order.status,
            }
        await PaymentEventProcessor(self.session, self.provider).ingest(
            ProviderEvent(
                event_id=f"admin-reconcile:{provider_state.event_id}",
                event_type=event_type,
                provider_reference=provider_state.provider_reference,
                amount_minor=provider_state.amount_minor,
                currency=provider_state.currency,
            ),
            raw_payload={
                "id": f"admin-reconcile:{provider_state.event_id}",
                "type": event_type,
                "payment_reference": provider_state.provider_reference,
                "amount_minor": provider_state.amount_minor,
                "currency": provider_state.currency,
            },
            signature_verified=False,
        )
        await self.session.refresh(order)
        return {
            "payment_order_id": str(order.id),
            "action": "provider_state_applied",
            "status": order.status,
        }

    async def list_ledger(
        self,
        *,
        limit: int,
        cursor: str | None,
        user_id: uuid.UUID | None = None,
        category: str | None = None,
        created_from: datetime | None = None,
        created_to: datetime | None = None,
        sort_order: str = "desc",
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        statement = (
            select(CreditLedgerEntry, User.email)
            .join(User, User.id == CreditLedgerEntry.user_id)
        )
        if user_id is not None:
            statement = statement.where(CreditLedgerEntry.user_id == user_id)
        if category is not None:
            predicates = {
                "purchase": and_(
                    CreditLedgerEntry.reference_type == "payment_order",
                    CreditLedgerEntry.amount > 0,
                ),
                "spend": CreditLedgerEntry.entry_type == "charge",
                "refund": CreditLedgerEntry.entry_type == "refund",
                "adjustment": or_(
                    CreditLedgerEntry.entry_type == "release",
                    and_(
                        CreditLedgerEntry.reference_type == "admin_adjustment",
                        CreditLedgerEntry.amount <= 0,
                    ),
                ),
                "gift": or_(
                    and_(
                        CreditLedgerEntry.reference_type == "admin_adjustment",
                        CreditLedgerEntry.amount > 0,
                    ),
                    and_(
                        CreditLedgerEntry.entry_type == "grant",
                        CreditLedgerEntry.reference_type != "payment_order",
                    ),
                ),
            }
            predicate = predicates.get(category)
            if predicate is None:
                raise ApplicationError(
                    "VALIDATION_ERROR", "Invalid ledger category", status_code=400
                )
            statement = statement.where(predicate)
        if created_from is not None:
            statement = statement.where(CreditLedgerEntry.created_at >= created_from)
        if created_to is not None:
            statement = statement.where(CreditLedgerEntry.created_at <= created_to)
        if sort_order not in {"asc", "desc"}:
            raise ApplicationError(
                "VALIDATION_ERROR", "Invalid sort order", status_code=400
            )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            if sort_order == "asc":
                statement = statement.where(
                    or_(
                        CreditLedgerEntry.created_at > created_at,
                        and_(
                            CreditLedgerEntry.created_at == created_at,
                            CreditLedgerEntry.id > row_id,
                        ),
                    )
                )
            else:
                statement = statement.where(
                    or_(
                        CreditLedgerEntry.created_at < created_at,
                        and_(
                            CreditLedgerEntry.created_at == created_at,
                            CreditLedgerEntry.id < row_id,
                        ),
                    )
                )
        ordering = (
            (CreditLedgerEntry.created_at.asc(), CreditLedgerEntry.id.asc())
            if sort_order == "asc"
            else (CreditLedgerEntry.created_at.desc(), CreditLedgerEntry.id.desc())
        )
        rows = list((await self.session.execute(statement.order_by(*ordering).limit(limit + 1))).all())
        has_more = len(rows) > limit
        selected = rows[:limit]
        items = [
            {
                "id": str(row[0].id),
                "user_id": str(row[0].user_id),
                "user_email": row[1],
                "category": _ledger_category(row[0]),
                "type": row[0].entry_type,
                "amount": row[0].amount,
                "balance_after": row[0].balance_after,
                "reference_type": row[0].reference_type,
                "reference_id": row[0].reference_id,
                "reason": row[0].details.get("reason"),
                "counts_as_purchase": bool(
                    row[0].details.get("counts_as_purchase", False)
                ),
                "created_at": row[0].created_at,
            }
            for row in selected
        ]
        next_cursor = (
            _encode_cursor(selected[-1][0].created_at, selected[-1][0].id)
            if has_more and selected
            else None
        )
        return items, next_cursor, has_more

    async def stuck_reservations(
        self,
        *,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        terminal = [status.value for status in TERMINAL_RECORDING_STATUSES]
        statement = (
            select(CreditReservation, Recording)
            .join(Recording, Recording.id == CreditReservation.recording_id)
            .where(
                CreditReservation.status == "active",
                Recording.status.in_(terminal),
            )
        )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    CreditReservation.created_at < created_at,
                    and_(
                        CreditReservation.created_at == created_at,
                        CreditReservation.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.execute(
                    statement.order_by(
                        CreditReservation.created_at.desc(),
                        CreditReservation.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        selected = rows[:limit]
        items = [self._reservation_payload(row[0], row[1]) for row in selected]
        next_cursor = (
            _encode_cursor(selected[-1][0].created_at, selected[-1][0].id)
            if has_more and selected
            else None
        )
        return items, next_cursor, has_more

    @staticmethod
    def _reservation_payload(
        reservation: CreditReservation, recording: Recording
    ) -> dict[str, object]:
        return {
            "id": str(reservation.id),
            "user_id": str(reservation.user_id),
            "recording_id": str(reservation.recording_id),
            "recording_status": recording.status,
            "reserved": reservation.reserved,
            "settled": reservation.settled,
            "released": reservation.released,
            "remaining_reserved": max(
                reservation.reserved - reservation.settled - reservation.released,
                0,
            ),
            "created_at": reservation.created_at,
        }

    async def release_stuck_reservation(
        self, reservation_id: str, *, reason: str
    ) -> tuple[dict[str, object], int]:
        parsed = _parse_uuid(reservation_id, "Credit reservation")
        reservation = await self.session.scalar(
            select(CreditReservation)
            .where(CreditReservation.id == parsed)
            .with_for_update()
        )
        if reservation is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Credit reservation not found", status_code=404
            )
        recording = await self.session.get(Recording, reservation.recording_id)
        if recording is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Recording not found", status_code=404
            )
        terminal = {status.value for status in TERMINAL_RECORDING_STATUSES}
        if recording.status not in terminal:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Reservation can only be released after the recording has ended",
                status_code=409,
            )
        released = await CreditService(self.session).release_recording(
            recording_id=recording.id,
            reason=reason,
        )
        await self.session.flush()
        return self._reservation_payload(reservation, recording), released
