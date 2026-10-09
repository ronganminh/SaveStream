from app.domain.common.errors import ApplicationError
from typing import cast

from app.settings import (
    AppSettings,
    StorePurchasePlatform,
    store_purchase_platform_enabled,
)

from .base import StoreReceiptVerifier
from .disabled import DisabledStoreReceiptVerifier
from .fake import FakeStoreReceiptVerifier
from .apple import AppleStoreReceiptVerifier
from .google_play import GooglePlayReceiptVerifier


def store_receipt_verifier_for_platform(
    settings: AppSettings,
    platform: str,
) -> StoreReceiptVerifier:
    normalized_value = platform.strip().lower()
    if normalized_value not in {"app_store", "google_play"}:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Unsupported store platform",
            status_code=400,
        )
    normalized = cast(StorePurchasePlatform, normalized_value)
    if settings.store_purchase_provider == "disabled":
        return DisabledStoreReceiptVerifier(normalized)
    if settings.store_purchase_provider == "fake":
        if settings.environment == "production":
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Fake store verification is disabled in production",
                status_code=503,
            )
        return FakeStoreReceiptVerifier(normalized)
    if not store_purchase_platform_enabled(
        settings.store_purchase_provider,
        normalized,
    ):
        return DisabledStoreReceiptVerifier(normalized)
    if normalized == "app_store":
        return AppleStoreReceiptVerifier(settings)
    return GooglePlayReceiptVerifier(settings)
