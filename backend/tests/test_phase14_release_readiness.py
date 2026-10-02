from __future__ import annotations

import pytest

from app.application.billing.service import _validate_checkout_return_url
from app.domain.common.errors import ApplicationError
from app.release.readiness import ReleaseManifest, validate_release
from app.settings import AppSettings
from config import Settings as RuntimeSettings


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
        cors_allow_origins=(
            "https://savestream.online",
            "https://www.savestream.online",
        ),
    )


def test_checkout_return_url_is_locked_to_frontend_success_route() -> None:
    settings = _release_settings()
    accepted = _validate_checkout_return_url(
        settings,
        "https://savestream.online/billing/success?order_id=abc",
    )
    assert accepted == "https://savestream.online/billing/success?order_id=abc"

    alternate = _validate_checkout_return_url(
        settings,
        "https://www.savestream.online/billing/success?order_id=abc",
    )
    assert alternate.startswith("https://www.savestream.online/billing/success")

    with pytest.raises(ApplicationError, match="allowed frontend origin"):
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


def test_release_validator_accepts_canonical_production_manifest() -> None:
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
        payment_provider="lemonsqueezy",
        payment_provider_base_url="https://api.lemonsqueezy.com/v1",
        payment_provider_api_key="live-api-key",
        payment_webhook_secret="live-webhook-secret",
        lemon_squeezy_store_id="123",
        lemon_squeezy_variant_id="456",
        metrics_token="metrics-token",
        ops_alert_email="ops@savestream.online",
        trusted_proxy_cidrs=("172.16.0.0/12",),
        force_https=True,
        security_headers_enabled=True,
        recording_source_backend="tiktok",
    )
    runtime = RuntimeSettings(
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
    manifest = ReleaseManifest(
        api_origin="https://api.savestream.online",
        frontend_origin="https://savestream.online",
        payment_webhook_url=(
            "https://api.savestream.online"
            "/v1/webhooks/payments/lemonsqueezy"
        ),
    )
    assert validate_release(settings, runtime, manifest) == []


def test_release_validator_rejects_insecure_storage_and_missing_alerts() -> None:
    settings = AppSettings(
        environment="production",
        database_url="sqlite+aiosqlite:///:memory:",
        redis_url="redis://localhost:6379/0",
        celery_broker_url="memory://",
        celery_result_backend="cache+memory://",
        minio_endpoint="http://storage:9000",
        minio_access_key="savestream",
        minio_secret_key="savestream-local-only",
        frontend_base_url="https://savestream.online",
        cors_allow_origins=("https://savestream.online",),
        smtp_host="smtp-relay.brevo.com",
        smtp_starttls=True,
        payment_provider="lemonsqueezy",
        payment_provider_base_url="https://api.lemonsqueezy.com/v1",
        lemon_squeezy_store_id="123",
        lemon_squeezy_variant_id="456",
        trusted_proxy_cidrs=("172.16.0.0/12",),
        force_https=True,
        security_headers_enabled=True,
        recording_source_backend="tiktok",
    )
    runtime = RuntimeSettings(
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
    errors = validate_release(
        settings,
        runtime,
        ReleaseManifest(
            api_origin="https://api.savestream.online",
            frontend_origin="https://savestream.online",
            payment_webhook_url=(
                "https://api.savestream.online"
                "/v1/webhooks/payments/lemonsqueezy"
            ),
        ),
    )
    assert "Production S3/MinIO transport must use TLS" in errors
    assert "Production storage access key must not use the local default" in errors
    assert "Production storage secret must not use the local default" in errors
    assert "SAVESTREAM_OPS_ALERT_EMAIL must be configured" in errors
