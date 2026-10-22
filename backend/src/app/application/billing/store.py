from __future__ import annotations

import hashlib
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
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

# Google refunds a purchase that is not acknowledged within 3 days.
PLAY_ACKNOWLEDGE_WINDOW = timedelta(days=3)


def play_account_reference(user_id: uuid.UUID) -> str:
    """The obfuscatedAccountId the Android app sets on every purchase.

    SHA-256 of the SaveStream user id, so a purchase token can't be redeemed
    by another account and Google never sees the raw id.
    """
    return hashlib.sha256(str(user_id).encode("utf-8")).hexdigest()


def store_order_reference(platform: str, transaction_id: str, store_token: str | None) -> str:
    """payment_orders.provider_reference for a store purchase.

    Google Play uses the purchase token (orderId is empty for promo codes);
    tokens can be long, so only their hash is the reference.
    """
    if platform == "google_play" and store_token:
        return "token:" + hashlib.sha256(store_token.encode("utf-8")).hexdigest()
    return transaction_id


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


@dataclass(frozen=True, slots=True)
class StorePurchaseResult:
    status: Literal["credited", "pending", "payment_pending", "rejected"]
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
        *,
        require_account_reference: bool = False,
    ) -> None:
        self.session = session
        self.verifier = verifier
        self.require_account_reference = require_account_reference

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
        if verified.account_reference is not None:
            if verified.account_reference != play_account_reference(user_id):
                raise self._invalid_receipt(
                    "Store purchase belongs to another account"
                )
        elif self.require_account_reference and self.verifier.platform == "google_play":
            raise self._invalid_receipt("Store purchase is not linked to an account")
        package = await self._package(product_id)

        existing = await self._order_for(verified)
        if existing is not None:
            if existing.user_id != user_id or existing.package_id != package.id:
                raise self._invalid_receipt(
                    "Store transaction is already linked to another purchase"
                )
            return await self._settle(existing, verified)

        paid = not verified.pending
        order = PaymentOrder(
            user_id=user_id,
            package_id=package.id,
            status=(PaymentStatus.PAID if paid else PaymentStatus.PENDING).value,
            credits=package.credits,
            amount_minor=package.amount_minor,
            currency=package.currency,
            provider=self.verifier.platform,
            provider_reference=store_order_reference(
                self.verifier.platform, transaction_id, verified.store_token
            ),
            store_token=verified.store_token
            if self.verifier.platform == "google_play"
            else None,
            paid_at=(verified.purchased_at or utcnow()) if paid else None,
        )
        self.session.add(order)
        await self.session.flush()
        return await self._settle(order, verified, new=True)

    async def resume(self, order: PaymentOrder) -> StorePurchaseResult:
        """Re-check a Google Play order: grant a pending one that settled,
        retry acknowledge/consume. Used by the retry job and RTDN."""
        if not order.store_token:
            raise self._invalid_receipt("Store order has no purchase token")
        package = await self.session.get(CreditPackage, order.package_id)
        product_id = package.google_play_product_id if package is not None else None
        if not product_id:
            raise self._invalid_receipt("Store product is not configured")
        verified = await self.verifier.verify_purchase(
            product_id=product_id,
            transaction_id=order.store_token,
            receipt=order.store_token,
        )
        return await self._settle(order, verified)

    async def handle_purchased_notification(
        self, *, product_id: str, store_token: str, raw_payload: dict[str, object]
    ) -> StorePurchaseResult | None:
        """RTDN PURCHASED: finish an order the app started but could not complete.

        A purchase the app never reported can't be matched to a user (Google
        only knows a hash of the user id), so it is recorded for support; the
        app reports it on its next start, and Google refunds it after 3 days
        if it never does.
        """
        reference = store_order_reference("google_play", store_token, store_token)
        order = await self.session.scalar(
            select(PaymentOrder).where(
                PaymentOrder.provider == "google_play",
                PaymentOrder.provider_reference == reference,
            )
        )
        if order is not None:
            return await self.resume(order)
        event_id = "unclaimed:" + reference.removeprefix("token:")[:40]
        exists = await self.session.scalar(
            select(PaymentEvent.id).where(
                PaymentEvent.provider == "google_play",
                PaymentEvent.provider_event_id == event_id,
            )
        )
        if exists is None:
            self.session.add(
                PaymentEvent(
                    provider="google_play",
                    provider_event_id=event_id,
                    event_type="purchase.unclaimed",
                    provider_reference=reference,
                    payload={"product_id": product_id, "notification": raw_payload},
                    signature_verified=True,
                    processed_at=utcnow(),
                )
            )
            await self.session.commit()
        return None

    async def retry_unfinished(self, *, now: datetime | None = None) -> dict[str, int]:
        """Google Play orders still pending payment or not acknowledged."""
        now = now or utcnow()
        orders = list(
            (
                await self.session.scalars(
                    select(PaymentOrder).where(
                        PaymentOrder.provider == "google_play",
                        PaymentOrder.store_token.is_not(None),
                        PaymentOrder.created_at >= now - PLAY_ACKNOWLEDGE_WINDOW - timedelta(days=1),
                        (PaymentOrder.status == PaymentStatus.PENDING.value)
                        | (PaymentOrder.failure_code == "store_finalize_pending"),
                    )
                )
            ).all()
        )
        counts = {"checked": 0, "credited": 0, "failed": 0}
        for order in orders:
            counts["checked"] += 1
            try:
                result = await self.resume(order)
            except ApplicationError:
                await self.session.rollback()
                counts["failed"] += 1
                continue
            if result.status == "credited":
                counts["credited"] += 1
        return counts

    async def reconcile_voided(self, refunds: list[VerifiedStoreRefund]) -> int:
        """Apply refunds found by the daily Voided Purchases check."""
        applied = 0
        for refund in refunds:
            result = await self.apply_refund(
                refund, raw_payload={"source": "voided_purchases_api"}
            )
            applied += int(result.applied)
        return applied

    async def _order_for(self, verified: VerifiedStorePurchase) -> PaymentOrder | None:
        reference = store_order_reference(
            self.verifier.platform, verified.transaction_id, verified.store_token
        )
        candidates = [reference]
        if reference != verified.transaction_id:
            # Orders from before the token reference used the orderId.
            candidates.append(verified.transaction_id)
        return await self.session.scalar(
            select(PaymentOrder).where(
                PaymentOrder.provider == self.verifier.platform,
                PaymentOrder.provider_reference.in_(candidates),
            )
        )

    async def _settle(
        self,
        order: PaymentOrder,
        verified: VerifiedStorePurchase,
        *,
        new: bool = False,
    ) -> StorePurchaseResult:
        if order.store_token is None and verified.store_token and order.provider == "google_play":
            order.store_token = verified.store_token
        if verified.pending:
            await self.session.commit()
            balance = await CreditService(self.session).balance(order.user_id)
            return StorePurchaseResult(
                status="payment_pending",
                payment_order_id=order.id,
                cloud_minutes_added=0,
                cloud_minutes_available=balance.available,
            )
        newly_paid = new
        if PaymentStatus(order.status) is PaymentStatus.PENDING:
            order.status = transition_payment(
                PaymentStatus.PENDING, PaymentStatus.PAID
            ).value
            order.paid_at = verified.purchased_at or utcnow()
            newly_paid = True
        if PaymentStatus(order.status) not in {
            PaymentStatus.PAID,
            PaymentStatus.PARTIALLY_REFUNDED,
        }:
            raise self._invalid_receipt("Store purchase was refunded or cancelled")
        await BillingCreditService(self.session).grant_purchase(
            user_id=order.user_id,
            payment_order_id=order.id,
            credits=order.credits,
            # Same key as before the token reference for older orders, whose
            # provider_reference is the transaction id.
            idempotency_reference=(
                f"store:{self.verifier.platform}:{order.provider_reference}:grant"
            ),
        )
        await ensure_purchase_completed_notification(self.session, order)
        await self.session.commit()
        await self.session.refresh(order)

        status = await self._finalize(order, verified)
        balance = await CreditService(self.session).balance(order.user_id)
        return StorePurchaseResult(
            status=status,
            payment_order_id=order.id,
            cloud_minutes_added=order.credits if newly_paid else 0,
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
        references = [refund.transaction_id]
        if refund.store_token:
            references.insert(
                0,
                store_order_reference(refund.platform, refund.transaction_id, refund.store_token),
            )
        order = await self.session.scalar(
            select(PaymentOrder)
            .where(
                PaymentOrder.provider == refund.platform,
                PaymentOrder.provider_reference.in_(references),
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
