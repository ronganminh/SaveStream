from __future__ import annotations

import json
from datetime import datetime
from typing import Mapping

from app.domain.common.errors import ApplicationError

from .base import StoreReceiptVerifier, VerifiedStorePurchase, VerifiedStoreRefund


class FakeStoreReceiptVerifier(StoreReceiptVerifier):
    def __init__(self, platform: str) -> None:
        self.platform = platform
        self.finalized: list[str] = []

    async def verify_purchase(
        self,
        *,
        product_id: str,
        transaction_id: str,
        receipt: str,
    ) -> VerifiedStorePurchase:
        try:
            payload = json.loads(receipt)
        except json.JSONDecodeError as exc:
            raise ApplicationError(
                "STORE_RECEIPT_INVALID",
                "Store receipt is invalid",
                status_code=422,
            ) from exc
        if (
            not isinstance(payload, dict)
            or payload.get("valid") is not True
            or payload.get("platform") != self.platform
        ):
            raise ApplicationError(
                "STORE_RECEIPT_INVALID",
                "Store receipt is invalid",
                status_code=422,
            )
        verified_product = str(payload.get("product_id") or "")
        verified_transaction = str(payload.get("transaction_id") or "")
        if verified_product != product_id or verified_transaction != transaction_id:
            raise ApplicationError(
                "STORE_RECEIPT_INVALID",
                "Store receipt does not match the requested purchase",
                status_code=422,
            )
        purchased_at_raw = payload.get("purchased_at")
        purchased_at = (
            datetime.fromisoformat(str(purchased_at_raw))
            if purchased_at_raw
            else None
        )
        return VerifiedStorePurchase(
            platform=self.platform,
            product_id=verified_product,
            transaction_id=verified_transaction,
            purchased_at=purchased_at,
        )

    async def finalize_purchase(
        self,
        purchase: VerifiedStorePurchase,
    ) -> None:
        self.finalized.append(purchase.transaction_id)

    async def verify_refund_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> VerifiedStoreRefund:
        del headers
        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise ApplicationError(
                "STORE_RECEIPT_INVALID",
                "Store notification is invalid",
                status_code=422,
            ) from exc
        if (
            not isinstance(payload, dict)
            or payload.get("valid") is not True
            or payload.get("platform") != self.platform
            or payload.get("type") != "refund"
        ):
            raise ApplicationError(
                "STORE_RECEIPT_INVALID",
                "Store notification is invalid",
                status_code=422,
            )
        return VerifiedStoreRefund(
            platform=self.platform,
            transaction_id=str(payload.get("transaction_id") or ""),
            event_id=str(payload.get("event_id") or ""),
        )
