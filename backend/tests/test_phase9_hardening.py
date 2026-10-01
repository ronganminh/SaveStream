from __future__ import annotations

import uuid
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient

from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.infrastructure.security.tokens import TokenError, TokenService
from app.main import create_app
from app.settings import AppSettings
from tests.identity_helpers import identity_settings


class BrokenRateLimiter:
    async def hit(self, **kwargs) -> None:
        del kwargs
        raise RuntimeError("redis unavailable")


def test_phase9_secret_file_and_jwt_rotation(tmp_path, monkeypatch) -> None:
    secret_file = tmp_path / "jwt-secret"
    secret_file.write_text("secret-from-mounted-file", encoding="utf-8")
    monkeypatch.delenv("SAVESTREAM_JWT_SECRET", raising=False)
    monkeypatch.setenv("SAVESTREAM_JWT_SECRET_FILE", str(secret_file))
    settings = AppSettings.from_env()
    assert settings.jwt_secret == "secret-from-mounted-file"

    old = identity_settings("sqlite+aiosqlite:///:memory:")
    old_token, _ = TokenService(old).issue_access_token(
        user_id=uuid.uuid4(),
        session_id=uuid.uuid4(),
    )
    rotated = replace(
        old,
        jwt_secret="phase9-new-signing-secret-that-is-long-enough",
        jwt_previous_secrets=(old.jwt_secret,),
    )
    claims = TokenService(rotated).decode_access_token(old_token)
    assert isinstance(claims.user_id, uuid.UUID)

    new_token, _ = TokenService(rotated).issue_access_token(
        user_id=uuid.uuid4(),
        session_id=uuid.uuid4(),
    )
    with pytest.raises(TokenError):
        TokenService(old).decode_access_token(new_token)


def test_phase9_security_headers_and_https_enforcement(tmp_path) -> None:
    settings = replace(
        identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase9-security.db'}"
        ),
        force_https=True,
    )
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        response = client.get("/health/live")
        assert response.status_code == 200
        assert response.headers["x-content-type-options"] == "nosniff"
        assert response.headers["x-frame-options"] == "DENY"
        assert response.headers["referrer-policy"] == "no-referrer"
        assert "max-age=31536000" in response.headers["strict-transport-security"]

    app_http = create_app(settings)
    with TestClient(app_http, base_url="http://testserver") as client:
        response = client.get("/health/live")
        assert response.status_code == 400
        assert response.json()["error"]["message"] == "HTTPS is required"


def test_phase9_global_rate_limit_and_dependency_failure(tmp_path) -> None:
    settings = replace(
        identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'phase9-rate.db'}"
        ),
        api_rate_limit=1,
        api_rate_window_seconds=60,
    )

    app = create_app(settings)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        first = client.get("/v1/me")
        second = client.get("/v1/me")
        assert first.status_code == 401
        assert second.status_code == 429
        assert second.json()["error"]["code"] == "RATE_LIMITED"

    broken_app = create_app(settings)
    with TestClient(broken_app, base_url="https://testserver") as client:
        broken_app.state.rate_limiter = BrokenRateLimiter()
        response = client.get("/v1/me")
        assert response.status_code == 503
        assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"


def test_phase9_production_config_requires_hardened_values(monkeypatch) -> None:
    values = {
        "SAVESTREAM_ENVIRONMENT": "production",
        "SAVESTREAM_DATABASE_URL": "postgresql+asyncpg://user:pass@db:5432/savestream",
        "SAVESTREAM_REDIS_URL": "redis://redis:6379/0",
        "SAVESTREAM_JWT_SECRET": "production-jwt-secret-that-is-at-least-thirty-two-chars",
        "SAVESTREAM_FRONTEND_BASE_URL": "https://app.example.test",
        "SAVESTREAM_CORS_ALLOW_ORIGINS": "https://app.example.test",
        "SAVESTREAM_SMTP_HOST": "smtp-relay.brevo.com",
        "SAVESTREAM_SMTP_PORT": "587",
        "SAVESTREAM_SMTP_USERNAME": "smtp-login",
        "SAVESTREAM_SMTP_PASSWORD": "smtp-key",
        "SAVESTREAM_SMTP_STARTTLS": "true",
        "SAVESTREAM_EMAIL_FROM": "SaveStream <no-reply@example.test>",
        "SAVESTREAM_PAYMENT_PROVIDER": "gateway",
        "SAVESTREAM_PAYMENT_PROVIDER_BASE_URL": "https://payments.example.test",
        "SAVESTREAM_PAYMENT_PROVIDER_API_KEY": "provider-key",
        "SAVESTREAM_PAYMENT_WEBHOOK_SECRET": "provider-webhook-secret",
        "SAVESTREAM_METRICS_TOKEN": "metrics-secret",
        "SAVESTREAM_TRUSTED_PROXY_CIDRS": "10.0.0.0/8",
        "SAVESTREAM_FORCE_HTTPS": "true",
        "SAVESTREAM_API_RATE_LIMIT": "300",
        "SAVESTREAM_QUOTA_MAX_WATCHES_PER_USER": "100",
        "SAVESTREAM_QUOTA_MAX_RECORDINGS_PER_DAY": "100",
        "SAVESTREAM_QUOTA_MAX_ACTIVE_RECORDINGS_PER_USER": "2",
    }
    for key, value in values.items():
        monkeypatch.setenv(key, value)
    settings = AppSettings.from_env()
    assert settings.environment == "production"
    assert settings.force_https is True
    assert settings.api_rate_limit == 300
    assert create_app(settings).openapi_url is None

    monkeypatch.setenv("SAVESTREAM_CORS_ALLOW_ORIGINS", "http://app.example.test")
    with pytest.raises(ValueError, match="Production CORS"):
        AppSettings.from_env()
