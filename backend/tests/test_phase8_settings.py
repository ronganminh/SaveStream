import pytest

from app.settings import AppSettings


def test_phase8_production_requires_nondefault_metrics_token(monkeypatch) -> None:
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "production")
    monkeypatch.setenv("SAVESTREAM_JWT_SECRET", "production-jwt-secret")
    monkeypatch.setenv("SAVESTREAM_SMTP_HOST", "smtp-relay.brevo.com")
    monkeypatch.setenv("SAVESTREAM_SMTP_PORT", "587")
    monkeypatch.setenv("SAVESTREAM_SMTP_USERNAME", "smtp-login")
    monkeypatch.setenv("SAVESTREAM_SMTP_PASSWORD", "smtp-key")
    monkeypatch.setenv("SAVESTREAM_SMTP_STARTTLS", "true")
    monkeypatch.setenv(
        "SAVESTREAM_EMAIL_FROM",
        "SaveStream <no-reply@example.test>",
    )
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER", "gateway")
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER_BASE_URL", "https://payments.example")
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER_API_KEY", "provider-key")
    monkeypatch.setenv("SAVESTREAM_PAYMENT_WEBHOOK_SECRET", "provider-webhook-secret")
    monkeypatch.delenv("SAVESTREAM_METRICS_TOKEN", raising=False)
    with pytest.raises(ValueError, match="METRICS_TOKEN"):
        AppSettings.from_env()
