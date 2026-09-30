from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from tests.identity_helpers import identity_settings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_phase7_billing_operation_ids_match_frozen_contract() -> None:
    frozen = json.loads(CONTRACT.read_text(encoding="utf-8"))
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()

    expected = {
        ("/billing/packages", "get"): "listCreditPackages",
        ("/billing/payment-orders", "post"): "createPaymentOrder",
        ("/billing/payment-orders", "get"): "listPaymentOrders",
        (
            "/billing/payment-orders/{payment_order_id}",
            "get",
        ): "getPaymentOrder",
        (
            "/billing/payment-orders/{payment_order_id}/checkout",
            "post",
        ): "createPaymentCheckout",
        (
            "/webhooks/payments/{provider}",
            "post",
        ): "paymentWebhook",
    }
    for (path, method), operation_id in expected.items():
        actual = "/v1" + path
        assert actual in generated["paths"]
        assert generated["paths"][actual][method]["operationId"] == operation_id

    assert frozen["components"]["schemas"]["PaymentStatus"]["enum"] == [
        "created",
        "pending",
        "paid",
        "failed",
        "cancelled",
        "expired",
        "partially_refunded",
        "refunded",
    ]


def test_payment_webhook_has_no_bearer_security_requirement() -> None:
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()
    webhook = generated["paths"]["/v1/webhooks/payments/{provider}"]["post"]
    assert not webhook.get("security")
