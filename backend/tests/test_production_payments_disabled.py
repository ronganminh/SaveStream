from __future__ import annotations

import asyncio
from dataclasses import replace

import pytest

from app.domain.common.errors import ApplicationError
from app.infrastructure.payments.disabled import DisabledPaymentProvider
from app.infrastructure.payments.factory import (
    payment_provider_for_name,
    selected_payment_provider,
)
from app.release.readiness import ReleaseManifest, validate_release
from app.settings import AppSettings
from config import Settings as RuntimeSettings

_WEBHOOK_URL = "https://api.savestream.online/v1/webhooks/payments/lemonsqueezy"


def _production_env(monkeypatch) -> None:
    values = {
        "SAVESTREAM_ENVIRONMENT": "production",
        "SAVESTREAM_DATABASE_URL": "postgresql+asyncpg://user:password@db:5432/savestream",
        "SAVESTREAM_REDIS_URL": "redis://redis:6379/0",
        "SAVESTREAM_JWT_SECRET": "production-jwt-secret-at-least-thirty-two-characters",
        "SAVESTREAM_FRONTEND_BASE_URL": "https://savestream.online",
        "SAVESTREAM_CORS_ALLOW_ORIGINS": "https://savestream.online,https://www.savestream.online",
        "SAVESTREAM_SMTP_HOST": "smtp-relay.brevo.com",
        "SAVESTREAM_SMTP_PORT": "587",
        "SAVESTREAM_SMTP_USERNAME": "smtp-login",
        "SAVESTREAM_SMTP_PASSWORD": "smtp-key",
        "SAVESTREAM_SMTP_STARTTLS": "true",
        "SAVESTREAM_EMAIL_FROM": "SaveStream <no-reply@savestream.online>",
        "SAVESTREAM_METRICS_TOKEN": "metrics-secret",
        "SAVESTREAM_TRUSTED_PROXY_CIDRS": "172.16.0.0/12",
        "SAVESTREAM_FORCE_HTTPS": "true",
        "SAVESTREAM_SECURITY_HEADERS_ENABLED": "true",
    }
    for key, value in values.items():
        monkeypatch.setenv(key, value)


def _settings(**overrides) -> AppSettings:
    settings = AppSettings(
        environment="production",
        database_url="postgresql+asyncpg://user:password@db:5432/savestream",
        redis_url="redis://redis:6379/0",
        celery_broker_url="redis://redis:6379/1",
        celery_result_backend="redis://redis:6379/2",
        minio_endpoint="https://account.r2.cloudflarestorage.com",
        minio_access_key="production-r2-access",
        minio_secret_key="production-r2-secret",
        minio_bucket="savestream-recordings",
        minio_secure=True,
        frontend_base_url="https://savestream.online",
        cors_allow_origins=(
            "https://savestream.online",
            "https://www.savestream.online",
        ),
        smtp_host="smtp-relay.brevo.com",
        smtp_username="smtp-login",
        smtp_password="smtp-key",
        smtp_starttls=True,
        payment_provider="disabled",
        payment_provider_base_url="https://api.lemonsqueezy.com/v1",
        payment_provider_api_key="payments-disabled",
        payment_webhook_secret="payments-disabled",
        metrics_token="metrics-token",
        ops_alert_email="ops@savestream.online",
        trusted_proxy_cidrs=("172.16.0.0/12",),
        force_https=True,
        security_headers_enabled=True,
        recording_source_backend="tiktok",
    )
    return replace(settings, **overrides)


def _runtime() -> RuntimeSettings:
    return RuntimeSettings(
        environment="production",
        log_level=20,
        log_format="json",
        http_timeout_seconds=15.0,
        http_stream_timeout_seconds=30.0,
        proxy_check_timeout_seconds=10.0,
        update_timeout_seconds=15.0,
        cookies_file=None,
        telegram_config_file=None,
    )


def _manifest(*, allow_disabled_payments: bool) -> ReleaseManifest:
    return ReleaseManifest(
        api_origin="https://api.savestream.online",
        frontend_origin="https://savestream.online",
        payment_webhook_url=_WEBHOOK_URL,
        allow_disabled_payments=allow_disabled_payments,
    )


def test_production_settings_accept_disabled_payments_without_provider_secrets(
    monkeypatch,
) -> None:
    _production_env(monkeypatch)
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER", "disabled")
    settings = AppSettings.from_env()
    assert settings.payment_provider == "disabled"


def test_production_lemonsqueezy_rejects_disabled_placeholder_key(monkeypatch) -> None:
    _production_env(monkeypatch)
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER", "lemonsqueezy")
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER_API_KEY", "payments-disabled")
    monkeypatch.setenv("SAVESTREAM_PAYMENT_WEBHOOK_SECRET", "live-webhook-secret")
    monkeypatch.setenv("SAVESTREAM_LEMON_SQUEEZY_STORE_ID", "123")
    monkeypatch.setenv("SAVESTREAM_LEMON_SQUEEZY_VARIANT_ID", "456")
    with pytest.raises(ValueError, match="PAYMENT_PROVIDER_API_KEY"):
        AppSettings.from_env()


def test_disabled_provider_fails_closed() -> None:
    settings = _settings()
    provider = selected_payment_provider(settings)
    assert isinstance(provider, DisabledPaymentProvider)

    with pytest.raises(ApplicationError, match="Payments are not enabled") as checkout:
        asyncio.run(
            provider.create_checkout(
                order_id="order",
                amount_minor=100,
                currency="USD",
                return_url="https://savestream.online/billing/success",
            )
        )
    assert checkout.value.status_code == 503
    with pytest.raises(ApplicationError, match="Payments are not enabled"):
        provider.verify_and_parse_webhook(b"{}", {"X-Signature": "forged"})
    assert asyncio.run(provider.retrieve_payment("ref")) is None


def test_webhook_provider_lookup_fails_closed_when_payments_disabled() -> None:
    for name in ("lemonsqueezy", "fake", "gateway"):
        with pytest.raises(ApplicationError) as exc:
            payment_provider_for_name(_settings(), name)
        assert exc.value.status_code == 503


def test_release_validator_requires_explicit_opt_in_for_disabled_payments() -> None:
    errors = validate_release(
        _settings(),
        _runtime(),
        _manifest(allow_disabled_payments=False),
    )
    assert errors == [
        "SAVESTREAM_PAYMENT_PROVIDER=disabled requires --allow-disabled-payments"
    ]
    assert (
        validate_release(
            _settings(),
            _runtime(),
            _manifest(allow_disabled_payments=True),
        )
        == []
    )


def test_release_validator_rejects_placeholder_key_for_live_payments() -> None:
    settings = _settings(
        payment_provider="lemonsqueezy",
        lemon_squeezy_store_id="123",
        lemon_squeezy_variant_id="456",
    )
    errors = validate_release(
        settings,
        _runtime(),
        _manifest(allow_disabled_payments=True),
    )
    assert errors == ["Payment API key is still the payments-disabled placeholder"]
