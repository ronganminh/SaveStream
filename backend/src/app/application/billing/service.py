from __future__ import annotations

import base64
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.billing.state import PaymentStatus, transition_payment
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import (
    CreditPackage,
    PaymentEvent,
    PaymentOrder,
    Refund,
)
from app.infrastructure.db.models import IdempotencyKey
from app.infrastructure.payments.base import PaymentProvider, ProviderEvent
from app.settings import AppSettings

from .credits import BillingCreditService


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _hash_request(payload: dict[str, object]) -> str:
    import hashlib

    canonical = json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def encode_cursor(order: PaymentOrder) -> str:
    payload = json.dumps(
        {
            "created_at": aware(order.created_at).isoformat(),
            "id": str(order.id),
        },
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(
            base64.urlsafe_b64decode(padded).decode("utf-8")
        )
        return (
            datetime.fromisoformat(payload["created_at"]),
            uuid.UUID(payload["id"]),
        )
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid pagination cursor",
            status_code=400,
        ) from exc


def _validate_idempotency_key(value: str) -> None:
    try:
        uuid.UUID(value)
    except ValueError as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Idempotency-Key must be a UUID",
            status_code=400,
        ) from exc


def _validate_checkout_return_url(settings: AppSettings, value: str) -> str:
    parsed = urlparse(value)
    if (
        parsed.scheme not in {"http", "https"}
        or not parsed.netloc
        or parsed.username
        or parsed.password
        or parsed.fragment
    ):
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Checkout return URL must be an absolute http(s) URL without credentials or fragment",
            status_code=400,
        )
    if settings.environment in {"staging", "production"}:
        actual_origin = f"{parsed.scheme}://{parsed.netloc}"
        allowed_origins = set(settings.cors_allow_origins) or {
            settings.frontend_base_url
        }
        if parsed.scheme != "https" or actual_origin not in allowed_origins:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Checkout return URL must use an allowed frontend origin",
                status_code=400,
            )
        if parsed.path != "/billing/success":
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Checkout return URL must target /billing/success",
                status_code=400,
            )
    return value


@dataclass(frozen=True, slots=True)
class BillingPage:
    items: list[PaymentOrder]
    next_cursor: str | None
    has_more: bool


@dataclass(frozen=True, slots=True)
class CheckoutResult:
    checkout_url: str
    payment_order: PaymentOrder


class BillingService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        provider: PaymentProvider,
    ) -> None:
        self.session = session
        self.settings = settings
        self.provider = provider

    async def packages(self) -> list[CreditPackage]:
        return list(
            (
                await self.session.scalars(
                    select(CreditPackage)
                    .where(CreditPackage.active.is_(True))
                    .order_by(CreditPackage.credits, CreditPackage.id)
                )
            ).all()
        )

    async def create_order(
        self,
        *,
        user_id: uuid.UUID,
        package_id: str,
        idempotency_key: str,
    ) -> PaymentOrder:
        _validate_idempotency_key(idempotency_key)
        try:
            parsed_package_id = uuid.UUID(package_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Credit package not found",
                status_code=404,
            ) from exc

        namespace = f"billing:create-order:{user_id}"
        digest = _hash_request({"package_id": package_id})
        existing_key = await self.session.scalar(
            select(IdempotencyKey).where(
                IdempotencyKey.namespace == namespace,
                IdempotencyKey.key == idempotency_key,
            )
        )
        if existing_key is not None:
            if existing_key.request_hash != digest:
                raise ApplicationError(
                    "IDEMPOTENCY_KEY_REUSED",
                    "Idempotency key was already used with a different request",
                    status_code=409,
                )
            order_id = (existing_key.response_body or {}).get("payment_order_id")
            if order_id:
                replay = await self.session.scalar(
                    select(PaymentOrder).where(
                        PaymentOrder.id == uuid.UUID(str(order_id)),
                        PaymentOrder.user_id == user_id,
                    )
                )
                if replay is not None:
                    return replay

        package = await self.session.scalar(
            select(CreditPackage).where(
                CreditPackage.id == parsed_package_id,
                CreditPackage.active.is_(True),
            )
        )
        if package is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Credit package not found",
                status_code=404,
            )

        order = PaymentOrder(
            user_id=user_id,
            package_id=package.id,
            status=PaymentStatus.CREATED.value,
            credits=package.credits,
            amount_minor=package.amount_minor,
            currency=package.currency,
        )
        self.session.add(order)
        await self.session.flush()
        self.session.add(
            IdempotencyKey(
                namespace=namespace,
                key=idempotency_key,
                request_hash=digest,
                response_status=201,
                response_body={"payment_order_id": str(order.id)},
                expires_at=utcnow()
                + timedelta(seconds=self.settings.idempotency_ttl_seconds),
            )
        )
        await self.session.commit()
        await self.session.refresh(order)
        return order

    async def get(
        self,
        *,
        user_id: uuid.UUID,
        payment_order_id: str,
    ) -> PaymentOrder:
        try:
            parsed = uuid.UUID(payment_order_id)
        except ValueError as exc:
            raise self._not_found() from exc
        order = await self.session.scalar(
            select(PaymentOrder).where(
                PaymentOrder.id == parsed,
                PaymentOrder.user_id == user_id,
            )
        )
        if order is None:
            raise self._not_found()
        return order

    async def list(
        self,
        *,
        user_id: uuid.UUID,
        limit: int,
        cursor: str | None,
    ) -> BillingPage:
        statement = select(PaymentOrder).where(
            PaymentOrder.user_id == user_id
        )
        if cursor:
            created_at, order_id = decode_cursor(cursor)
            statement = statement.where(
                or_(
                    PaymentOrder.created_at < created_at,
                    and_(
                        PaymentOrder.created_at == created_at,
                        PaymentOrder.id < order_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.scalars(
                    statement.order_by(
                        PaymentOrder.created_at.desc(),
                        PaymentOrder.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        items = rows[:limit]
        next_cursor = (
            encode_cursor(items[-1])
            if has_more and items
            else None
        )
        return BillingPage(items, next_cursor, has_more)

    async def checkout(
        self,
        *,
        user_id: uuid.UUID,
        payment_order_id: str,
        return_url: str,
        idempotency_key: str,
    ) -> CheckoutResult:
        _validate_idempotency_key(idempotency_key)
        return_url = _validate_checkout_return_url(self.settings, return_url)
        order = await self.get(
            user_id=user_id,
            payment_order_id=payment_order_id,
        )
        namespace = f"billing:checkout:{user_id}:{order.id}"
        digest = _hash_request({"return_url": return_url})
        existing_key = await self.session.scalar(
            select(IdempotencyKey).where(
                IdempotencyKey.namespace == namespace,
                IdempotencyKey.key == idempotency_key,
            )
        )
        if existing_key is not None:
            if existing_key.request_hash != digest:
                raise ApplicationError(
                    "IDEMPOTENCY_KEY_REUSED",
                    "Idempotency key was already used with a different request",
                    status_code=409,
                )
            if order.checkout_url:
                return CheckoutResult(order.checkout_url, order)

        status = PaymentStatus(order.status)
        if status is PaymentStatus.PENDING and order.checkout_url:
            checkout_url = order.checkout_url
        elif status is PaymentStatus.CREATED:
            session = await self.provider.create_checkout(
                order_id=str(order.id),
                amount_minor=order.amount_minor,
                currency=order.currency,
                return_url=return_url,
            )
            order.provider = self.provider.name
            order.provider_reference = session.provider_reference
            order.checkout_url = session.checkout_url
            order.return_url = return_url
            order.status = transition_payment(
                status,
                PaymentStatus.PENDING,
            ).value
            checkout_url = session.checkout_url
        else:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Payment order cannot create a checkout in its current state",
                status_code=409,
                details={"status": order.status},
            )

        if existing_key is None:
            self.session.add(
                IdempotencyKey(
                    namespace=namespace,
                    key=idempotency_key,
                    request_hash=digest,
                    response_status=200,
                    response_body={
                        "payment_order_id": str(order.id),
                        "checkout_url": checkout_url,
                    },
                    expires_at=utcnow()
                    + timedelta(seconds=self.settings.idempotency_ttl_seconds),
                )
            )
        await self.session.commit()
        await self.session.refresh(order)
        return CheckoutResult(checkout_url, order)

    @staticmethod
    def _not_found() -> ApplicationError:
        return ApplicationError(
            "RESOURCE_NOT_FOUND",
            "Payment order not found",
            status_code=404,
        )


class PaymentEventProcessor:
    def __init__(
        self,
        session: AsyncSession,
        provider: PaymentProvider,
    ) -> None:
        self.session = session
        self.provider = provider

    async def ingest(
        self,
        event: ProviderEvent,
        *,
        raw_payload: dict[str, object],
        signature_verified: bool,
    ) -> bool:
        existing = await self.session.scalar(
            select(PaymentEvent).where(
                PaymentEvent.provider == self.provider.name,
                PaymentEvent.provider_event_id == event.event_id,
            )
        )
        if existing is not None:
            return False

        stored_payload = dict(raw_payload)
        if event.payment_order_id is not None:
            stored_payload["_payment_order_id"] = event.payment_order_id
        row = PaymentEvent(
            provider=self.provider.name,
            provider_event_id=event.event_id,
            event_type=event.event_type,
            provider_reference=event.provider_reference,
            payload=stored_payload,
            signature_verified=signature_verified,
        )
        self.session.add(row)
        await self.session.flush()
        await self._process(row, event)
        await self.session.commit()
        return True

    async def reprocess_pending(self, *, limit: int = 100) -> int:
        rows = list(
            (
                await self.session.scalars(
                    select(PaymentEvent)
                    .where(PaymentEvent.processed_at.is_(None))
                    .order_by(PaymentEvent.received_at, PaymentEvent.id)
                    .limit(limit)
                )
            ).all()
        )
        processed = 0
        for row in rows:
            event = ProviderEvent(
                event_id=row.provider_event_id,
                event_type=row.event_type,
                provider_reference=row.provider_reference,
                payment_order_id=(
                    str(row.payload["_payment_order_id"])
                    if row.payload.get("_payment_order_id") is not None
                    else None
                ),
                amount_minor=(
                    int(row.payload["amount_minor"])
                    if row.payload.get("amount_minor") is not None
                    else None
                ),
                currency=(
                    str(row.payload["currency"]).upper()
                    if row.payload.get("currency") is not None
                    else None
                ),
                refund_reference=(
                    str(row.payload["refund_reference"])
                    if row.payload.get("refund_reference") is not None
                    else None
                ),
            )
            before = row.processed_at
            await self._process(row, event)
            if before is None and row.processed_at is not None:
                processed += 1
        await self.session.commit()
        return processed

    async def _process(
        self,
        row: PaymentEvent,
        event: ProviderEvent,
    ) -> None:
        order = None
        if event.payment_order_id is not None:
            try:
                parsed_order_id = uuid.UUID(event.payment_order_id)
            except ValueError:
                parsed_order_id = None
            if parsed_order_id is not None:
                order = await self.session.scalar(
                    select(PaymentOrder)
                    .where(
                        PaymentOrder.provider == self.provider.name,
                        PaymentOrder.id == parsed_order_id,
                    )
                    .with_for_update()
                )
        if order is None:
            order = await self.session.scalar(
                select(PaymentOrder)
                .where(
                    PaymentOrder.provider == self.provider.name,
                    PaymentOrder.provider_reference
                    == event.provider_reference,
                )
                .with_for_update()
            )
        if order is None:
            row.processing_error = "payment_order_not_found_or_not_ready"
            return
        row.payment_order_id = order.id
        if (
            event.payment_order_id is not None
            and event.provider_reference
            and order.provider_reference != event.provider_reference
        ):
            order.provider_reference = event.provider_reference

        if event.event_type == "payment.paid":
            if (
                event.amount_minor != order.amount_minor
                or event.currency != order.currency
            ):
                row.processing_error = "payment_amount_or_currency_mismatch"
                return
            status = PaymentStatus(order.status)
            if status is PaymentStatus.CREATED:
                row.processing_error = "checkout_not_committed_yet"
                return
            if status is PaymentStatus.PENDING:
                order.status = transition_payment(
                    status,
                    PaymentStatus.PAID,
                ).value
                order.paid_at = utcnow()
            elif status not in {
                PaymentStatus.PAID,
                PaymentStatus.PARTIALLY_REFUNDED,
                PaymentStatus.REFUNDED,
            }:
                row.processing_error = f"payment_not_payable_from_{status.value}"
                return
            await BillingCreditService(self.session).grant_purchase(
                user_id=order.user_id,
                payment_order_id=order.id,
                credits=order.credits,
            )
            row.processing_error = None
            row.processed_at = utcnow()
            return

        payment_failure_map = {
            "payment.failed": PaymentStatus.FAILED,
            "payment.cancelled": PaymentStatus.CANCELLED,
            "payment.expired": PaymentStatus.EXPIRED,
        }
        if event.event_type in payment_failure_map:
            current = PaymentStatus(order.status)
            if current in {PaymentStatus.CREATED, PaymentStatus.PENDING}:
                order.status = transition_payment(
                    current,
                    payment_failure_map[event.event_type],
                ).value
                order.failure_code = event.event_type
                order.failure_message = event.event_type.replace(".", " ")
            row.processing_error = None
            row.processed_at = utcnow()
            return

        if event.event_type in {"refund.succeeded", "refund.failed"}:
            if not event.refund_reference:
                row.processing_error = "refund_reference_missing"
                return
            refund = await self.session.scalar(
                select(Refund)
                .where(
                    Refund.provider == self.provider.name,
                    Refund.provider_refund_reference
                    == event.refund_reference,
                    Refund.payment_order_id == order.id,
                )
                .with_for_update()
            )
            if refund is None:
                row.processing_error = "refund_not_found_or_not_ready"
                return
            if (
                event.amount_minor is not None
                and event.amount_minor != refund.amount_minor
            ):
                row.processing_error = "refund_amount_mismatch"
                return

            if event.event_type == "refund.failed":
                if refund.status in {"created", "pending"}:
                    await BillingCreditService(
                        self.session
                    ).compensate_failed_refund(
                        user_id=refund.user_id,
                        refund_id=refund.id,
                        credits=refund.credits,
                    )
                    refund.status = "failed"
                    refund.failure_message = "provider_refund_failed"
                row.processing_error = None
                row.processed_at = utcnow()
                return

            if refund.status == "failed":
                row.processing_error = "refund_succeeded_after_failed_compensation"
                return
            if refund.status != "succeeded":
                refund.status = "succeeded"
                refund.succeeded_at = utcnow()
                order.refunded_credits += refund.credits
                order.refunded_amount_minor += refund.amount_minor
                target = (
                    PaymentStatus.REFUNDED
                    if (
                        order.refunded_credits == order.credits
                        and order.refunded_amount_minor == order.amount_minor
                    )
                    else PaymentStatus.PARTIALLY_REFUNDED
                )
                order.status = transition_payment(
                    PaymentStatus(order.status),
                    target,
                ).value
            row.processing_error = None
            row.processed_at = utcnow()
            return

        row.processing_error = None
        row.processed_at = utcnow()


class BillingAdminService:
    def __init__(
        self,
        session: AsyncSession,
        provider: PaymentProvider,
    ) -> None:
        self.session = session
        self.provider = provider

    async def create_package(
        self,
        *,
        code: str,
        name: str,
        credits: int,
        amount_minor: int,
        currency: str,
    ) -> CreditPackage:
        normalized_currency = currency.strip().upper()
        if (
            credits <= 0
            or amount_minor < 0
            or len(normalized_currency) != 3
        ):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid credit package",
                status_code=400,
            )
        existing = await self.session.scalar(
            select(CreditPackage).where(CreditPackage.code == code)
        )
        if existing is not None:
            return existing
        package = CreditPackage(
            code=code,
            name=name,
            credits=credits,
            amount_minor=amount_minor,
            currency=normalized_currency,
            active=True,
        )
        self.session.add(package)
        await self.session.commit()
        await self.session.refresh(package)
        return package

    async def disable_package(self, package_id: str) -> None:
        try:
            parsed = uuid.UUID(package_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Credit package not found",
                status_code=404,
            ) from exc
        package = await self.session.get(CreditPackage, parsed)
        if package is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Credit package not found",
                status_code=404,
            )
        package.active = False
        await self.session.commit()

    async def request_refund(
        self,
        *,
        payment_order_id: str,
        amount_minor: int,
        credits: int,
        idempotency_key: str,
    ) -> Refund:
        _validate_idempotency_key(idempotency_key)
        try:
            parsed = uuid.UUID(payment_order_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Payment order not found",
                status_code=404,
            ) from exc

        request_key = f"refund-request:{idempotency_key}"
        existing = await self.session.scalar(
            select(Refund).where(Refund.request_key == request_key)
        )
        if existing is not None:
            if (
                existing.payment_order_id != parsed
                or existing.amount_minor != amount_minor
                or existing.credits != credits
            ):
                raise ApplicationError(
                    "IDEMPOTENCY_KEY_REUSED",
                    "Refund idempotency key was reused with a different request",
                    status_code=409,
                )
            return existing

        order = await self.session.scalar(
            select(PaymentOrder)
            .where(PaymentOrder.id == parsed)
            .with_for_update()
        )
        if order is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Payment order not found",
                status_code=404,
            )
        if PaymentStatus(order.status) not in {
            PaymentStatus.PAID,
            PaymentStatus.PARTIALLY_REFUNDED,
        }:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Payment order is not refundable",
                status_code=409,
            )
        if not order.provider or not order.provider_reference:
            raise ApplicationError(
                "PAYMENT_FAILED",
                "Payment provider reference is missing",
                status_code=409,
            )
        if amount_minor <= 0 or credits <= 0:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Refund amount and credits must be positive",
                status_code=400,
            )

        pending_totals = await self.session.execute(
            select(
                func.coalesce(func.sum(Refund.amount_minor), 0),
                func.coalesce(func.sum(Refund.credits), 0),
            ).where(
                Refund.payment_order_id == order.id,
                Refund.status.in_(["created", "pending", "succeeded"]),
            )
        )
        pending_amount, pending_credits = pending_totals.one()
        if (
            int(pending_amount) + amount_minor > order.amount_minor
            or int(pending_credits) + credits > order.credits
        ):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Refund exceeds the original payment order",
                status_code=409,
            )

        refund = Refund(
            payment_order_id=order.id,
            user_id=order.user_id,
            status="created",
            credits=credits,
            amount_minor=amount_minor,
            provider=order.provider,
            request_key=request_key,
        )
        self.session.add(refund)
        await self.session.flush()
        await BillingCreditService(self.session).hold_refund(
            user_id=order.user_id,
            refund_id=refund.id,
            credits=credits,
        )
        try:
            provider_refund = await self.provider.create_refund(
                refund_id=str(refund.id),
                provider_reference=order.provider_reference,
                amount_minor=amount_minor,
                currency=order.currency,
            )
        except ApplicationError:
            await BillingCreditService(
                self.session
            ).compensate_failed_refund(
                user_id=order.user_id,
                refund_id=refund.id,
                credits=credits,
            )
            refund.status = "failed"
            refund.failure_message = "provider_refund_request_failed"
            await self.session.commit()
            raise

        refund.provider_refund_reference = (
            provider_refund.provider_refund_reference
        )
        refund.status = "pending"
        await self.session.commit()
        await self.session.refresh(refund)
        return refund


class BillingReconciliationService:
    def __init__(
        self,
        session: AsyncSession,
        provider: PaymentProvider,
    ) -> None:
        self.session = session
        self.provider = provider
        self.processor = PaymentEventProcessor(session, provider)

    async def run_once(self, *, limit: int = 100) -> int:
        processed = await self.processor.reprocess_pending(limit=limit)
        orders = list(
            (
                await self.session.scalars(
                    select(PaymentOrder)
                    .where(
                        PaymentOrder.provider == self.provider.name,
                        PaymentOrder.status == PaymentStatus.PENDING.value,
                        PaymentOrder.provider_reference.is_not(None),
                    )
                    .order_by(PaymentOrder.updated_at)
                    .limit(limit)
                )
            ).all()
        )
        for order in orders:
            if not order.provider_reference:
                continue
            payment_state = await self.provider.retrieve_payment(
                order.provider_reference
            )
            if payment_state is None:
                continue
            event_type = {
                "paid": "payment.paid",
                "failed": "payment.failed",
                "cancelled": "payment.cancelled",
                "expired": "payment.expired",
                "pending": "payment.pending",
            }.get(payment_state.status)
            if event_type and event_type != "payment.pending":
                accepted = await self.processor.ingest(
                    ProviderEvent(
                        event_id=f"reconcile:{payment_state.event_id}",
                        event_type=event_type,
                        provider_reference=payment_state.provider_reference,
                        amount_minor=payment_state.amount_minor,
                        currency=payment_state.currency,
                    ),
                    raw_payload={
                        "id": f"reconcile:{payment_state.event_id}",
                        "type": event_type,
                        "payment_reference": payment_state.provider_reference,
                        "amount_minor": payment_state.amount_minor,
                        "currency": payment_state.currency,
                    },
                    signature_verified=False,
                )
                processed += int(accepted)

        refunds = list(
            (
                await self.session.scalars(
                    select(Refund)
                    .where(
                        Refund.provider == self.provider.name,
                        Refund.status == "pending",
                        Refund.provider_refund_reference.is_not(None),
                    )
                    .order_by(Refund.updated_at)
                    .limit(limit)
                )
            ).all()
        )
        for refund in refunds:
            if not refund.provider_refund_reference:
                continue
            refund_state = await self.provider.retrieve_refund(
                refund.provider_refund_reference
            )
            if refund_state is None or refund_state.status == "pending":
                continue
            event_type = (
                "refund.succeeded"
                if refund_state.status == "succeeded"
                else "refund.failed"
            )
            accepted = await self.processor.ingest(
                ProviderEvent(
                    event_id=f"reconcile:{refund_state.event_id}",
                    event_type=event_type,
                    provider_reference=refund_state.provider_reference,
                    amount_minor=refund_state.amount_minor,
                    refund_reference=refund_state.refund_reference,
                ),
                raw_payload={
                    "id": f"reconcile:{refund_state.event_id}",
                    "type": event_type,
                    "payment_reference": refund_state.provider_reference,
                    "refund_reference": refund_state.refund_reference,
                    "amount_minor": refund_state.amount_minor,
                },
                signature_verified=False,
            )
            processed += int(accepted)
        return processed
