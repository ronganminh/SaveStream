from __future__ import annotations

import json
from pathlib import Path

from app.main import create_app
from tests.identity_helpers import identity_settings

CONTRACT = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_phase6_credit_operation_ids_match_frozen_contract() -> None:
    frozen = json.loads(CONTRACT.read_text(encoding="utf-8"))
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()

    expected = {
        "/credits/balance": "getCreditBalance",
        "/credits/transactions": "listCreditTransactions",
        "/credits/reservations": "listCreditReservations",
        "/pricing": "getPricing",
    }
    for path, operation_id in expected.items():
        actual = "/v1" + path
        assert actual in generated["paths"]
        assert generated["paths"][actual]["get"]["operationId"] == operation_id

    assert frozen["components"]["schemas"]["CreditReservation"]["properties"][
        "status"
    ]["enum"] == ["active", "settled", "released"]
    assert frozen["components"]["schemas"]["CreditTransaction"]["properties"][
        "type"
    ]["enum"] == ["grant", "charge", "release", "adjustment", "refund"]


def test_phase6_does_not_add_unfrozen_public_admin_credit_route() -> None:
    generated = create_app(
        identity_settings("sqlite+aiosqlite:///:memory:")
    ).openapi()
    assert "/v1/admin/credits/adjustments" not in generated["paths"]
