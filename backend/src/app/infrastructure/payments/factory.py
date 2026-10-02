from app.domain.common.errors import ApplicationError
from app.settings import AppSettings

from .base import PaymentProvider
from .disabled import DisabledPaymentProvider
from .fake import FakePaymentProvider
from .lemonsqueezy import LemonSqueezyPaymentProvider
from .provider import ConfiguredHttpPaymentProvider


def selected_payment_provider(settings: AppSettings) -> PaymentProvider:
    return payment_provider_for_name(settings, settings.payment_provider)


def payment_provider_for_name(
    settings: AppSettings,
    provider_name: str,
) -> PaymentProvider:
    normalized = provider_name.strip().lower()
    if settings.payment_provider == "disabled":
        if normalized == "disabled":
            return DisabledPaymentProvider()
        raise ApplicationError(
            "SERVICE_UNAVAILABLE",
            "Payments are not enabled",
            status_code=503,
        )
    if normalized == "fake":
        if settings.environment == "production":
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Fake payment provider is disabled in production",
                status_code=503,
            )
        return FakePaymentProvider(settings)
    if normalized == "lemonsqueezy":
        if settings.payment_provider != "lemonsqueezy":
            raise ApplicationError(
                "RESOURCE_NOT_FOUND",
                "Payment provider not found",
                status_code=404,
            )
        if (
            not settings.payment_provider_api_key
            or not settings.lemon_squeezy_store_id
            or not settings.lemon_squeezy_variant_id
        ):
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Lemon Squeezy is not configured",
                status_code=503,
            )
        return LemonSqueezyPaymentProvider(settings)
    if normalized == settings.payment_provider:
        if not settings.payment_provider_base_url:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Payment provider is not configured",
                status_code=503,
            )
        return ConfiguredHttpPaymentProvider(settings)
    raise ApplicationError(
        "RESOURCE_NOT_FOUND",
        "Payment provider not found",
        status_code=404,
    )
