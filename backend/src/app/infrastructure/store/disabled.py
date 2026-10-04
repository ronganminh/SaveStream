from __future__ import annotations

from typing import Mapping

from app.domain.common.errors import ApplicationError

from .base import StoreReceiptVerifier, VerifiedStorePurchase, VerifiedStoreRefund


class DisabledStoreReceiptVerifier(StoreReceiptVerifier):
    def __init__(self, platform: str) -> None:
        self.platform = platform

    @staticmethod
    def _unavailable() -> ApplicationError:
        return ApplicationError(
            "SERVICE_UNAVAILABLE",
            "Store purchase verification is not enabled",
            status_code=503,
            retryable=True,
        )

    async def verify_purchase(
        self,
        *,
        product_id: str,
        transaction_id: str,
        receipt: str,
    ) -> VerifiedStorePurchase:
        del product_id, transaction_id, receipt
        raise self._unavailable()

    async def finalize_purchase(
        self,
        purchase: VerifiedStorePurchase,
    ) -> None:
        del purchase
        raise self._unavailable()

    async def verify_refund_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> VerifiedStoreRefund:
        del raw_body, headers
        raise self._unavailable()
