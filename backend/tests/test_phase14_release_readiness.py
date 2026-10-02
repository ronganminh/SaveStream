from __future__ import annotations

import pytest

from app.application.billing.service import _validate_checkout_return_url
from app.domain.common.errors import ApplicationError
from app.settings import AppSettings


def _production_env(monkeypatch) -> None:
    values = {
        "SAVESTREAM_ENVIRONMENT": "production",
        "SAVESTREAM_DATABASE_URL": "postgresql+asyncpg://user:password@db:5432/savestream",
        "SAVESTREAM_REDIS_URL": "redis://redis:6379/0",
        "SAVESTREAM_JWT_SECRET": "phase14-production-jwt-secret-at-least-thirty-two-characters",
        "SAVESTREAM_FRONTEND_BASE_URL": "https://savestream.online",
        "SAVESTREAM_CORS_ALLOW_ORIGINS": "https://savestream.online,https://www.savestream.online",
        "SAVESTREAM_SMTP_HOST": "smtp-relay.brevo.com",
        "SAVESTREAM_SMTP_PORT": "587",
        "SAVESTREAM_SMTP_USERNAME": "smtp-login",
        "SAVESTREAM_SMTP_PASSWORD": "smtp-key",
        "SAVESTREAM_SMTP_STARTTLS": "true",
        "SAVESTREAM_EMAIL_FROM": "SaveStream <no-reply@savestream.online>",
        "SAVESTREAM_PAYMENT_PROVIDER": "gateway",
        "SAVESTREAM_PAYMENT_PROVIDER_BASE_URL": "https://payments.example.test",
        "SAVESTREAM_PAYMENT_PROVIDER_API_KEY": "provider-key",
        "SAVESTREAM_PAYMENT_WEBHOOK_SECRET": "provider-webhook-secret",
        "SAVESTREAM_METRICS_TOKEN": "metrics-secret",
        "SAVESTREAM_TRUSTED_PROXY_CIDRS": "172.16.0.0/12",
        "SAVESTREAM_FORCE_HTTPS": "true",
        "SAVESTREAM_SECURITY_HEADERS_ENABLED": "true",
        "SAVESTREAM_API_RATE_LIMIT": "300",
        "SAVESTREAM_QUOTA_MAX_WATCHES_PER_USER": "100",
        "SAVESTREAM_QUOTA_MAX_RECORDINGS_PER_DAY": "100",
        "SAVESTREAM_QUOTA_MAX_ACTIVE_RECORDINGS_PER_USER": "2",
    }
    for key, value in values.items():
        monkeypatch.setenv(key, value)


def test_production_cors_must_include_exact_frontend_origin(monkeypatch) -> None:
    _production_env(monkeypatch)
    monkeypatch.setenv(
        "SAVESTREAM_CORS_ALLOW_ORIGINS",
        "https://www.savestream.online",
    )
    with pytest.raises(ValueError, match="must include SAVESTREAM_FRONTEND_BASE_URL"):
        AppSettings.from_env()


def test_production_rejects_non_origin_cors_entries(monkeypatch) -> None:
    _production_env(monkeypatch)
    monkeypatch.setenv(
        "SAVESTREAM_CORS_ALLOW_ORIGINS",
        "https://savestream.online/,https://www.savestream.online",
    )
    with pytest.raises(ValueError, match="exact origins"):
        AppSettings.from_env()


def test_production_requires_security_headers(monkeypatch) -> None:
    _production_env(monkeypatch)
    monkeypatch.setenv("SAVESTREAM_SECURITY_HEADERS_ENABLED", "false")
    with pytest.raises(ValueError, match="SECURITY_HEADERS_ENABLED"):
        AppSettings.from_env()


def _release_settings() -> AppSettings:
    return AppSettings(
        environment="production",
        database_url="sqlite+aiosqlite:///:memory:",
        redis_url="redis://localhost:6379/15",
        celery_broker_url="memory://",
        celery_result_backend="cache+memory://",
        minio_endpoint="https://example.r2.cloudflarestorage.com",
        minio_access_key="test-access",
        minio_secret_key="test-secret",
        frontend_base_url="https://savestream.online",
    )


def test_checkout_return_url_is_locked_to_frontend_success_route() -> None:
    settings = _release_settings()
    accepted = _validate_checkout_return_url(
        settings,
        "https://savestream.online/billing/success?order_id=abc",
    )
    assert accepted == "https://savestream.online/billing/success?order_id=abc"

    with pytest.raises(ApplicationError, match="configured frontend origin"):
        _validate_checkout_return_url(
            settings,
            "https://evil.example/billing/success?order_id=abc",
        )

    with pytest.raises(ApplicationError, match="/billing/success"):
        _validate_checkout_return_url(
            settings,
            "https://savestream.online/account",
        )


def test_checkout_return_url_rejects_credentials_and_fragments() -> None:
    settings = _release_settings()
    with pytest.raises(ApplicationError, match="without credentials or fragment"):
        _validate_checkout_return_url(
            settings,
            "https://user:pass@savestream.online/billing/success",
        )
    with pytest.raises(ApplicationError, match="without credentials or fragment"):
        _validate_checkout_return_url(
            settings,
            "https://savestream.online/billing/success#token",
        )
