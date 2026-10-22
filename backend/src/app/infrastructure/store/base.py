from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from typing import Literal, Mapping, Protocol


@dataclass(frozen=True, slots=True)
class VerifiedStorePurchase:
    platform: str
    product_id: str
    transaction_id: str
    purchased_at: datetime | None = None
    store_token: str | None = None
    needs_acknowledge: bool = False
    needs_consume: bool = False
    # Google Play: paid by a slow method (e.g. cash); grant only once it settles.
    pending: bool = False
    # Google Play obfuscatedExternalAccountId the app set when buying.
    account_reference: str | None = None


@dataclass(frozen=True, slots=True)
class VerifiedStoreRefund:
    platform: str
    transaction_id: str
    event_id: str
    store_token: str | None = None


@dataclass(frozen=True, slots=True)
class StoreNotification:
    """A verified store server notification, reduced to what billing acts on."""

    kind: Literal["refund", "purchased", "ignored"]
    refund: VerifiedStoreRefund | None = None
    product_id: str | None = None
    store_token: str | None = None


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
