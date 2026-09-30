from __future__ import annotations

import hashlib
import hmac
import json

import pytest

from app.domain.common.errors import ApplicationError
from app.infrastructure.payments.fake import FakePaymentProvider
from app.settings import AppSettings
from tests.identity_helpers import identity_settings


def test_fake_webhook_verifies_raw_body_signature() -> None:
    settings = identity_settings("sqlite+aiosqlite:///:memory:")
    provider = FakePaymentProvider(settings)
    raw = json.dumps(
        {
            "id": "evt-1",
            "type": "payment.paid",
            "payment_reference": "fake_pay_1",
            "amount_minor": 100,
            "currency": "USD",
        },
        separators=(",", ":"),
    ).encode("utf-8")
    signature = hmac.new(
        settings.payment_webhook_secret.encode("utf-8"),
        raw,
        hashlib.sha256,
    ).hexdigest()
    event = provider.verify_and_parse_webhook(
        raw,
        {"X-Payment-Signature": signature},
    )
    assert event.event_id == "evt-1"

    changed = raw + b" "
    with pytest.raises(ApplicationError) as forged:
        provider.verify_and_parse_webhook(
            changed,
            {"X-Payment-Signature": signature},
        )
    assert forged.value.status_code == 400


def test_production_settings_reject_fake_payment_provider(monkeypatch) -> None:
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "production")
    monkeypatch.setenv("SAVESTREAM_JWT_SECRET", "production-secret")
    monkeypatch.setenv("SAVESTREAM_PAYMENT_PROVIDER", "fake")
    with pytest.raises(ValueError, match="cannot be fake"):
        AppSettings.from_env()
