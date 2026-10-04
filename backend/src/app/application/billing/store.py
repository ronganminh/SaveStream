from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Literal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.billing.credits import BillingCreditService
from app.application.credits.service import CreditService
from app.application.notifications.service import (
    ensure_purchase_completed_notification,
)
from app.domain.billing.state import PaymentStatus, transition_payment
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import (
    CreditPackage,
    PaymentEvent,
    PaymentOrder,
)
from app.infrastructure.store.base import (
    StoreReceiptVerifier,
    VerifiedStorePurchase,
    VerifiedStoreRefund,
)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True, slots=True)
class StorePurchaseResult:
    status: Literal["credited", "pending", "rejected"]
    payment_order_id: uuid.UUID
    cloud_minutes_added: int
    cloud_minutes_available: int


@dataclass(frozen=True, slots=True)
class StoreRefundResult:
    applied: bool
    deducted_credits: int
    payment_order_id: uuid.UUID | None


class StorePurchaseService:
    def __init__(
        self,
        session: AsyncSession,
        verifier: StoreReceiptVerifier,
    ) -> None:
        self.session = session
        self.verifier = verifier

    async def purchase(
        self,
        *,
        user_id: uuid.UUID,
        product_id: str,
        transaction_id: str,
        receipt: str,
    ) -> StorePurchaseResult:
        verified = await self.verifier.verify_purchase(
            product_id=product_id,
            transaction_id=transaction_id,
            receipt=receipt,
        )
        if (
            verified.platform != self.verifier.platform
            or verified.product_id != product_id
            or verified.transaction_id != transaction_id
        ):
            raise self._invalid_receipt(
                "Verified purchase does not match the request"
            )
        package = await self._package(product_id)

        existing = await self.session.scalar(
            select(PaymentOrder).where(
                PaymentOrder.provider == self.verifier.platform,
                PaymentOrder.provider_reference == transaction_id,
            )
        )
        if existing is not None:
            if existing.user_id != user_id or existing.package_id != package.id:
                raise self._invalid_receipt(
                    "Store transaction is already linked to another purchase"
                )
            await BillingCreditService(self.session).grant_purchase(
                user_id=existing.user_id,
                payment_order_id=existing.id,
                credits=existing.credits,
                idempotency_reference=(
                    f"store:{self.verifier.platform}:"
                    f"{transaction_id}:grant"
                ),
            )
            await ensure_purchase_completed_notification(
                self.session,
                existing,
            )
            await self.session.commit()
            status = await self._finalize(existing, verified)
            balance = await CreditService(self.session).balance(user_id)
            return StorePurchaseResult(
                status=status,
                payment_order_id=existing.id,
                cloud_minutes_added=0,
                cloud_minutes_available=balance.available,
            )

        order = PaymentOrder(
            user_id=user_id,
            package_id=package.id,
            status=PaymentStatus.PAID.value,
            credits=package.credits,
            amount_minor=package.amount_minor,
            currency=package.currency,
            provider=self.verifier.platform,
            provider_reference=transaction_id,
            paid_at=verified.purchased_at or utcnow(),
        )
        self.session.add(order)
        await self.session.flush()
        await BillingCreditService(self.session).grant_purchase(
            user_id=user_id,
            payment_order_id=order.id,
            credits=order.credits,
            idempotency_reference=(
                f"store:{self.verifier.platform}:"
                f"{transaction_id}:grant"
            ),
        )
        await ensure_purchase_completed_notification(self.session, order)
        await self.session.commit()
        await self.session.refresh(order)

        status = await self._finalize(order, verified)
        balance = await CreditService(self.session).balance(user_id)
        return StorePurchaseResult(
            status=status,
            payment_order_id=order.id,
            cloud_minutes_added=order.credits,
            cloud_minutes_available=balance.available,
        )

    async def apply_refund(
        self,
        refund: VerifiedStoreRefund,
        *,
        raw_payload: dict[str, object],
    ) -> StoreRefundResult:
        if refund.platform != self.verifier.platform:
            raise self._invalid_receipt("Store refund platform mismatch")
        existing_event = await self.session.scalar(
            select(PaymentEvent).where(
                PaymentEvent.provider == refund.platform,
                PaymentEvent.provider_event_id == refund.event_id,
            )
        )
        if existing_event is not None:
            return StoreRefundResult(
                applied=False,
                deducted_credits=0,
                payment_order_id=existing_event.payment_order_id,
            )

        event = PaymentEvent(
            provider=refund.platform,
            provider_event_id=refund.event_id,
            event_type="refund.succeeded",
            provider_reference=refund.transaction_id,
            payload=dict(raw_payload),
            signature_verified=True,
        )
        self.session.add(event)
        order = await self.session.scalar(
            select(PaymentOrder)
            .where(
                PaymentOrder.provider == refund.platform,
                PaymentOrder.provider_reference == refund.transaction_id,
            )
            .with_for_update()
        )
        if order is None:
            event.processing_error = "payment_order_not_found"
            event.processed_at = utcnow()
            await self.session.commit()
            return StoreRefundResult(
                applied=False,
                deducted_credits=0,
                payment_order_id=None,
            )

        event.payment_order_id = order.id
        if PaymentStatus(order.status) is PaymentStatus.REFUNDED:
            event.processed_at = utcnow()
            await self.session.commit()
            return StoreRefundResult(
                applied=False,
                deducted_credits=0,
                payment_order_id=order.id,
            )
        if PaymentStatus(order.status) not in {
            PaymentStatus.PAID,
            PaymentStatus.PARTIALLY_REFUNDED,
        }:
            event.processing_error = (
                f"payment_not_refundable_from_{order.status}"
            )
            event.processed_at = utcnow()
            await self.session.commit()
            return StoreRefundResult(
                applied=False,
                deducted_credits=0,
                payment_order_id=order.id,
            )

        deducted = await BillingCreditService(
            self.session
        ).revoke_store_purchase(
            user_id=order.user_id,
            payment_order_id=order.id,
            event_id=refund.event_id,
            credits=max(order.credits - order.refunded_credits, 0),
        )
        order.refunded_credits = order.credits
        order.refunded_amount_minor = order.amount_minor
        order.status = transition_payment(
            PaymentStatus(order.status),
            PaymentStatus.REFUNDED,
        ).value
        event.processing_error = None
        event.processed_at = utcnow()
        await self.session.commit()
        return StoreRefundResult(
            applied=True,
            deducted_credits=deducted,
            payment_order_id=order.id,
        )

    async def _package(self, product_id: str) -> CreditPackage:
        if self.verifier.platform == "app_store":
            predicate = CreditPackage.app_store_product_id == product_id
        else:
            predicate = CreditPackage.google_play_product_id == product_id
        package = await self.session.scalar(
            select(CreditPackage).where(
                CreditPackage.active.is_(True),
                predicate,
            )
        )
        if package is None:
            raise self._invalid_receipt("Store product is not configured")
        return package

    async def _finalize(
        self,
        order: PaymentOrder,
        verified: VerifiedStorePurchase,
    ) -> Literal["credited", "pending"]:
        try:
            await self.verifier.finalize_purchase(verified)
        except ApplicationError as exc:
            order.failure_code = "store_finalize_pending"
            order.failure_message = exc.message
            await self.session.commit()
            return "pending"
        order.failure_code = None
        order.failure_message = None
        await self.session.commit()
        return "credited"

    @staticmethod
    def _invalid_receipt(message: str) -> ApplicationError:
        return ApplicationError(
            "STORE_RECEIPT_INVALID",
            message,
            status_code=422,
            retryable=False,
        )
