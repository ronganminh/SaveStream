"""Google Play purchases the server refuses: the reason is logged (the app
only shows a generic error)."""

from __future__ import annotations

import logging

import pytest
import sqlalchemy as sa

from app.application.billing.store import StorePurchaseService, play_account_reference
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import CreditPackage
from tests.test_play_billing_v2 import PRODUCT, FakePlay, _run, _seed, _settings, _verifier


def test_refused_purchase_logs_the_reason(tmp_path, caplog) -> None:
    settings = _settings(tmp_path, "log.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        package = await session.scalar(sa.select(CreditPackage))
        package.google_play_product_id = None
        await session.commit()
        play.buy("token-x", account=play_account_reference(user.id))
        with caplog.at_level(logging.WARNING), pytest.raises(ApplicationError):
            await StorePurchaseService(session, _verifier(settings, play)).purchase(
                user_id=user.id, product_id=PRODUCT, transaction_id="GPA.1", receipt="token-x"
            )

    _run(settings, body)
    assert "Store product is not configured" in caplog.text
    assert "STORE_RECEIPT_INVALID" in caplog.text
    assert "token-x" not in caplog.text


def test_play_lookup_failure_logs_the_http_status(tmp_path, caplog) -> None:
    settings = _settings(tmp_path, "status.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _seed(session)
        with caplog.at_level(logging.WARNING), pytest.raises(ApplicationError):
            # Unknown token: FakePlay answers 404.
            await StorePurchaseService(session, _verifier(settings, play)).purchase(
                user_id=user.id, product_id=PRODUCT, transaction_id="GPA.1", receipt="unknown-token"
            )

    _run(settings, body)
    assert "status=404" in caplog.text
    assert "unknown-token" not in caplog.text
