from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Mapping, Protocol


@dataclass(frozen=True, slots=True)
class VerifiedStorePurchase:
    platform: str
    product_id: str
    transaction_id: str
    purchased_at: datetime | None = None
    store_token: str | None = None
    needs_acknowledge: bool = False
    needs_consume: bool = False


@dataclass(frozen=True, slots=True)
class VerifiedStoreRefund:
    platform: str
    transaction_id: str
    event_id: str


class StoreReceiptVerifier(Protocol):
    platform: str

    async def verify_purchase(
        self,
        *,
        product_id: str,
        transaction_id: str,
        receipt: str,
    ) -> VerifiedStorePurchase: ...

    async def finalize_purchase(
        self,
        purchase: VerifiedStorePurchase,
    ) -> None: ...

    async def verify_refund_notification(
        self,
        raw_body: bytes,
        headers: Mapping[str, str],
    ) -> VerifiedStoreRefund: ...
