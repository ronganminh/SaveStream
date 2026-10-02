from __future__ import annotations

import asyncio
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.application.billing.service import BillingAdminService
from app.application.credits.service import CreditService
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.models import User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.fake import FakePaymentProvider
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.credit_helpers import configure_test_pricing
from tests.identity_helpers import create_schema, identity_settings, one_time_token


def _seed_catalog(settings) -> None:
    async def run() -> None:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                await configure_test_pricing(session, credits_per_unit=1)
                admin = BillingAdminService(session, FakePaymentProvider(settings))
                await admin.create_package(
                    code="standard",
                    name="Standard",
                    credits=9000,
                    amount_minor=2499,
                    currency="USD",
                )
                await admin.create_package(
                    code="starter",
                    name="Starter",
                    credits=3000,
                    amount_minor=999,
                    currency="USD",
                )
        finally:
            await database.close()

    asyncio.run(run())


def test_public_pricing_is_readable_without_auth(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'public-pricing.db'}"
    settings = replace(
        identity_settings(database_url),
        signup_credits=10,
        quota_max_watches_per_user=20,
        quota_max_active_recordings_per_user=2,
        watch_max_concurrent_recordings_per_user=3,
    )
    create_schema(database_url)
    _seed_catalog(settings)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.get("/v1/public/pricing")

    assert response.status_code == 200
    assert "public" in response.headers["cache-control"]
    body = response.json()
    assert body["signup_credits"] == 10
    assert body["max_channels_per_user"] == 20
    assert body["max_concurrent_recordings_per_user"] == 2
    assert body["recording_rate"] == {
        "unit_seconds": 60,
        "credits_per_unit": 1,
        "minimum_credits": 0,
    }
    assert [
        (item["code"], item["credits"], item["price"], item["recording_minutes"])
        for item in body["packages"]
    ] == [
        ("starter", 3000, {"amount_minor": 999, "currency": "USD"}, 3000),
        ("standard", 9000, {"amount_minor": 2499, "currency": "USD"}, 9000),
    ]


def test_public_pricing_without_configuration_is_empty_not_an_error(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'public-empty.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.get("/v1/public/pricing")

    assert response.status_code == 200
    body = response.json()
    assert body["packages"] == []
    assert body["recording_rate"] is None
    assert body["signup_credits"] == 0
    assert body["max_channels_per_user"] is None


def _ledger_for(settings, email: str) -> tuple[int, list[tuple[str, str, int]]]:
    async def run() -> tuple[int, list[tuple[str, str, int]]]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                user = await session.scalar(select(User).where(User.normalized_email == email))
                assert user is not None
                account = await session.scalar(
                    select(CreditAccount).where(CreditAccount.user_id == user.id)
                )
                entries = (
                    await session.scalars(
                        select(CreditLedgerEntry).where(CreditLedgerEntry.user_id == user.id)
                    )
                ).all()
                return (
                    account.posted_balance if account else 0,
                    [(e.entry_type, e.reference_type, e.amount) for e in entries],
                )
        finally:
            await database.close()

    return asyncio.run(run())


def test_first_email_verification_grants_trial_credits_once(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'trial.db'}"
    settings = replace(identity_settings(database_url), signup_credits=10)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        assert client.post(
            "/v1/auth/register",
            json={
                "email": "trial@example.com",
                "password": "correct horse battery staple",
                "display_name": "Trial",
            },
        ).status_code == 201
        assert client.post(
            "/v1/auth/verify-email",
            json={"token": one_time_token(settings, "trial@example.com", "verify_email")},
        ).status_code == 200

    balance, entries = _ledger_for(settings, "trial@example.com")
    assert balance == 10
    assert entries == [("grant", "signup_bonus", 10)]

    async def grant_again() -> None:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                user = await session.scalar(
                    select(User).where(User.normalized_email == "trial@example.com")
                )
                assert user is not None
                await CreditService(session).grant_signup_credits(user.id, 10)
                await session.commit()
        finally:
            await database.close()

    asyncio.run(grant_again())
    assert _ledger_for(settings, "trial@example.com") == (10, [("grant", "signup_bonus", 10)])


def test_no_trial_credits_when_disabled(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'no-trial.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        client.post(
            "/v1/auth/register",
            json={
                "email": "plain@example.com",
                "password": "correct horse battery staple",
                "display_name": "Plain",
            },
        )
        assert client.post(
            "/v1/auth/verify-email",
            json={"token": one_time_token(settings, "plain@example.com", "verify_email")},
        ).status_code == 200

    assert _ledger_for(settings, "plain@example.com") == (0, [])
