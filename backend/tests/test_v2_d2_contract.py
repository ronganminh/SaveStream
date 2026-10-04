from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d2_admin_finance_openapi_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]
    expected = {
        "/admin/payments": ("get", "listAdminPayments"),
        "/admin/payments/export.csv": ("get", "exportAdminPaymentsCsv"),
        "/admin/payments/stuck": ("get", "listAdminStuckPayments"),
        "/admin/payments/{payment_order_id}": ("get", "getAdminPayment"),
        "/admin/payments/{payment_order_id}/refund-preview": ("get", "previewAdminRefund"),
        "/admin/payments/{payment_order_id}/refunds": ("post", "refundAdminPayment"),
        "/admin/payments/{payment_order_id}/reconcile": ("post", "reconcileAdminPayment"),
        "/admin/credits/ledger": ("get", "listAdminCreditLedger"),
        "/admin/credits/ledger/export.csv": ("get", "exportAdminCreditLedgerCsv"),
        "/admin/credits/adjustments": ("post", "adjustAdminCredit"),
        "/admin/credits/stuck-reservations": ("get", "listAdminStuckReservations"),
        "/admin/credits/stuck-reservations/{reservation_id}/release": (
            "post",
            "releaseAdminStuckReservation",
        ),
    }
    for path, (method, operation_id) in expected.items():
        assert paths[path][method]["operationId"] == operation_id

    schemas = document["components"]["schemas"]
    for name in (
        "AdminPaymentOrder",
        "AdminRefundPreview",
        "AdminRefundRequest",
        "AdminCreditAdjustmentRequest",
        "AdminLedgerEntry",
        "AdminStuckReservation",
    ):
        assert name in schemas

    assert (
        schemas["AdminCreditAdjustmentRequest"]["properties"]["counts_as_purchase"]["default"]
        is False
    )

    for path, method in (
        ("/admin/payments/{payment_order_id}/refunds", "post"),
        ("/admin/payments/{payment_order_id}/reconcile", "post"),
        ("/admin/credits/adjustments", "post"),
        ("/admin/credits/stuck-reservations/{reservation_id}/release", "post"),
    ):
        assert any(
            item["name"] == "X-Admin-Step-Up"
            for item in paths[path][method]["parameters"]
        )
