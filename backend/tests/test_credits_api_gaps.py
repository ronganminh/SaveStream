"""Credits API gaps found by the Android v2 Credits screens: entitlement pack
and trial fields, Play order id and reported price on payment orders, ledger
entry context, Retry-After on reward 429s, and the featured pack flag."""

from __future__ import annotations

import asyncio
import json
import uuid
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import event, select

from app.api.dependencies import get_current_principal
from app.api.schemas.local_recordings import CreateRewardRequest
from app.application.billing.store import StorePurchaseService, play_account_reference
from app.application.entitlements.service import EntitlementService
from app.application.recordings.service import utcnow
from app.application.rewards.service import RewardService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.local_recording_models import RewardIntent, RewardUserState
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from app.settings import AppSettings
from tests.identity_helpers import identity_settings
from tests.test_play_billing_v2 import PRODUCT, FakePlay, _verifier
from tests.test_play_billing_v2 import _settings as play_settings

T0 = datetime(2026, 10, 1, 12, 0, tzinfo=timezone.utc)


def _settings(tmp_path, name: str, **changes) -> AppSettings:
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}"),
        store_purchase_provider="fake",
        **changes,
    )


def _run(settings: AppSettings, body):
    async def wrapped():
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                return await body(session)
        finally:
            await database.close()

    return asyncio.run(wrapped())


async def _user(session, email: str = "buyer@example.com") -> User:
    user = User(
        email=email,
        normalized_email=email,
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


def _packages() -> list[CreditPackage]:
    return [
        CreditPackage(
            code=code,
            name=name,
            credits=credits,
            amount_minor=amount,
            currency="USD",
            active=True,
            google_play_product_id=product,
            display_order=index,
        )
        for index, (code, name, credits, amount, product) in enumerate(
            [
                ("starter", "Starter", 3_000, 999, "savestream.hours.50"),
                ("standard", "Standard", 9_000, 2_499, "savestream.hours.150"),
                ("premium", "Premium", 24_000, 5_999, "savestream.hours.400"),
            ]
        )
    ]


def _client(settings: AppSettings, user_id: uuid.UUID) -> TestClient:
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: AuthPrincipal(
        user_id, uuid.uuid4(), "user", scopes_for_role("user")
    )
    return TestClient(app, base_url="https://testserver")


def _fake_receipt(transaction_id: str, product_id: str, order_id: str | None) -> str:
    payload: dict[str, object] = {
        "valid": True,
        "platform": "google_play",
        "product_id": product_id,
        "transaction_id": transaction_id,
    }
    if order_id is not None:
        payload["order_id"] = order_id
    return json.dumps(payload)


def _ledger(account: CreditAccount, **values) -> CreditLedgerEntry:
    values.setdefault("reference_key", f"test:{uuid.uuid4()}")
    return CreditLedgerEntry(account_id=account.id, user_id=account.user_id, **values)


# --- 1 + 2 + 3: purchase over HTTP, then entitlement, orders and ledger ---------


def test_store_purchase_exposes_play_order_price_pack_and_ledger_context(tmp_path) -> None:
    settings = _settings(tmp_path, "purchase.db")

    async def seed(session):
        user = await _user(session)
        session.add_all(_packages())
        await session.commit()
        return user.id

    user_id = _run(settings, seed)
    with _client(settings, user_id) as client:
        before = client.get("/v1/me/entitlement").json()
        assert before["last_pack_name"] is None
        assert before["last_pack_minutes"] is None
        assert before["cloud_minutes_cycle_total"] is None
        assert before["trial_used"] is False

        bought = client.post(
            "/v1/billing/store-purchases",
            json={
                "platform": "google_play",
                "product_id": "savestream.hours.150",
                "transaction_id": "GPA.3301-0000-0000-00001",
                "receipt": _fake_receipt(
                    "GPA.3301-0000-0000-00001",
                    "savestream.hours.150",
                    "GPA.3301-0000-0000-00001",
                ),
                "price_amount_micros": 649_000_000_000,
                "price_currency_code": "vnd",
            },
        )
        assert bought.status_code == 200, bought.text
        assert bought.json()["status"] == "credited"

        orders = client.get("/v1/billing/payment-orders").json()["items"]
        assert len(orders) == 1
        order = orders[0]
        assert order["store_order_id"] == "GPA.3301-0000-0000-00001"
        assert order["client_price_amount_micros"] == 649_000_000_000
        assert order["client_price_currency"] == "VND"
        # The list price and order reference are unchanged.
        assert order["amount"] == {"amount_minor": 2_499, "currency": "USD"}
        assert order["provider_reference"] == "GPA.3301-0000-0000-00001"
        single = client.get(f"/v1/billing/payment-orders/{order['id']}").json()
        assert single["store_order_id"] == order["store_order_id"]

        entitlement = client.get("/v1/me/entitlement").json()
        assert entitlement["last_pack_name"] == "Standard"
        assert entitlement["last_pack_minutes"] == 9_000
        assert entitlement["cloud_minutes_cycle_total"] == 9_000
        assert entitlement["cloud_minutes_available"] == 9_000
        assert entitlement["trial_used"] is False

        ledger = client.get("/v1/credits/transactions").json()["items"]
        grant = next(item for item in ledger if item["reference_type"] == "payment_order")
        assert grant["store_order_id"] == "GPA.3301-0000-0000-00001"
        assert grant["package_name"] == "Standard"
        assert grant["recording_channel_username"] is None
        assert grant["recording_duration_seconds"] is None

        # SQLite stores created_at to the second: keep the two purchases apart.
        async def backdate(session) -> None:
            for entry in (await session.scalars(select(CreditLedgerEntry))).all():
                entry.created_at = T0
            await session.commit()

        _run(settings, backdate)

        # Price is optional and validated; old clients send none.
        rejected = client.post(
            "/v1/billing/store-purchases",
            json={
                "platform": "google_play",
                "product_id": "savestream.hours.50",
                "transaction_id": "GPA.2",
                "receipt": _fake_receipt("GPA.2", "savestream.hours.50", None),
                "price_currency_code": "US",
            },
        )
        assert rejected.status_code == 400
        plain = client.post(
            "/v1/billing/store-purchases",
            json={
                "platform": "google_play",
                "product_id": "savestream.hours.50",
                "transaction_id": "GPA.2",
                "receipt": _fake_receipt("GPA.2", "savestream.hours.50", None),
            },
        )
        assert plain.status_code == 200, plain.text
        orders = client.get("/v1/billing/payment-orders").json()["items"]
        newest = next(item for item in orders if item["provider_reference"] == "GPA.2")
        assert newest["store_order_id"] is None
        assert newest["client_price_amount_micros"] is None
        assert newest["client_price_currency"] is None
        # The newest paid pack is the "last pack".
        entitlement = client.get("/v1/me/entitlement").json()
        assert entitlement["last_pack_name"] == "Starter"
        assert entitlement["last_pack_minutes"] == 3_000
        assert entitlement["cloud_minutes_cycle_total"] == 12_000


def test_google_play_order_id_is_stored_and_backfilled(tmp_path) -> None:
    settings = play_settings(tmp_path, "play.db")
    play = FakePlay()

    async def body(session) -> None:
        user = await _user(session)
        session.add(
            CreditPackage(
                code="starter",
                name="Starter",
                credits=3_000,
                amount_minor=999,
                currency="USD",
                active=True,
                google_play_product_id=PRODUCT,
            )
        )
        await session.commit()
        service = StorePurchaseService(session, _verifier(settings, play))
        account = play_account_reference(user.id)

        play.buy("token-a", account=account, order_id="GPA.1111-2222-3333-44444")
        result = await service.purchase(
            user_id=user.id,
            product_id=PRODUCT,
            transaction_id="GPA.1111-2222-3333-44444",
            receipt="token-a",
            client_price_amount_micros=9_990_000,
            client_price_currency="USD",
        )
        order = await session.get(PaymentOrder, result.payment_order_id)
        assert order.store_order_id == "GPA.1111-2222-3333-44444"
        assert order.provider_reference.startswith("token:")
        assert (order.client_price_amount_micros, order.client_price_currency) == (
            9_990_000,
            "USD",
        )

        # Promo codes have no orderId.
        play.buy("token-b", account=account, order_id="")
        promo = await service.purchase(
            user_id=user.id, product_id=PRODUCT, transaction_id="token-b", receipt="token-b"
        )
        assert (await session.get(PaymentOrder, promo.payment_order_id)).store_order_id is None

        # An order from before the column learns its id when Play is asked again;
        # a later report never overwrites the first price.
        order.store_order_id = None
        await session.commit()
        await service.purchase(
            user_id=user.id,
            product_id=PRODUCT,
            transaction_id="GPA.1111-2222-3333-44444",
            receipt="token-a",
            client_price_amount_micros=1,
            client_price_currency="EUR",
        )
        await session.refresh(order)
        assert order.store_order_id == "GPA.1111-2222-3333-44444"
        assert order.client_price_amount_micros == 9_990_000

    _run(settings, body)


# --- 1: trial and cycle total ----------------------------------------------------


def test_entitlement_cycle_total_and_trial_used(tmp_path) -> None:
    settings = _settings(tmp_path, "cycle.db")

    async def body(session) -> None:
        user = await _user(session)
        account = CreditAccount(user_id=user.id, posted_balance=0)
        session.add(account)
        await session.flush()
        service = EntitlementService(session, settings)

        session.add(
            _ledger(
                account,
                entry_type="grant",
                amount=60,
                balance_after=60,
                reference_type="signup_bonus",
                reference_id=str(user.id),
                created_at=T0,
            )
        )
        account.posted_balance = 60
        await session.commit()
        snapshot = await service.get(user.id)
        assert snapshot.trial_used is True
        assert snapshot.cloud_minutes_cycle_total == 60
        assert snapshot.last_pack_name is None

        # A rewarded ad grows N; a recording charge does not shrink it.
        session.add_all(
            [
                _ledger(
                    account,
                    entry_type="grant",
                    amount=5,
                    balance_after=65,
                    reference_type="reward",
                    reference_id=str(uuid.uuid4()),
                    created_at=T0 + timedelta(minutes=1),
                ),
                _ledger(
                    account,
                    entry_type="charge",
                    amount=-40,
                    balance_after=25,
                    reference_type="recording",
                    reference_id=str(uuid.uuid4()),
                    created_at=T0 + timedelta(minutes=2),
                ),
            ]
        )
        account.posted_balance = 25
        await session.commit()
        snapshot = await service.get(user.id)
        assert snapshot.cloud_minutes_cycle_total == 65
        assert snapshot.cloud_minutes_posted == 25 <= snapshot.cloud_minutes_cycle_total

        # Buying a pack starts a new cycle from the balance after the grant.
        package = _packages()[0]
        session.add(package)
        await session.flush()
        order = PaymentOrder(
            user_id=user.id,
            package_id=package.id,
            status="paid",
            credits=3_000,
            amount_minor=999,
            currency="USD",
            provider="google_play",
            provider_reference="token:x",
            paid_at=T0 + timedelta(minutes=3),
        )
        session.add(order)
        await session.flush()
        session.add(
            _ledger(
                account,
                entry_type="grant",
                amount=3_000,
                balance_after=3_025,
                reference_type="payment_order",
                reference_id=str(order.id),
                created_at=T0 + timedelta(minutes=3),
            )
        )
        account.posted_balance = 3_025
        await session.commit()
        snapshot = await service.get(user.id)
        assert snapshot.cloud_minutes_cycle_total == 3_025
        assert snapshot.last_pack_name == "Starter"
        assert snapshot.last_pack_minutes == 3_000
        assert snapshot.trial_used is True

        # A refunded order is no longer "the last pack".
        order.status = "refunded"
        await session.commit()
        assert (await service.get(user.id)).last_pack_name is None

    _run(settings, body)


# --- 3: recording context without N+1 --------------------------------------------


def test_ledger_entries_carry_recording_channel_and_duration_in_two_queries(
    tmp_path,
) -> None:
    settings = _settings(tmp_path, "ledger.db")

    async def seed(session):
        user = await _user(session)
        other = await _user(session, "other@example.com")
        account = CreditAccount(user_id=user.id, posted_balance=0)
        session.add(account)
        await session.flush()
        recordings = [
            Recording(
                user_id=user.id,
                source_type="username",
                source_value=f"creator{index}",
                resolved_username=f"creator{index}",
                status="completed",
                duration_seconds=600 * (index + 1),
            )
            for index in range(5)
        ]
        foreign = Recording(
            user_id=other.id,
            source_type="username",
            source_value="someone",
            resolved_username="someone",
            status="completed",
            duration_seconds=60,
        )
        session.add_all([*recordings, foreign])
        await session.flush()
        for index, recording in enumerate(recordings):
            session.add(
                _ledger(
                    account,
                    entry_type="charge",
                    amount=-10,
                    balance_after=0,
                    reference_type="recording",
                    reference_id=str(recording.id),
                    created_at=T0 + timedelta(minutes=index),
                )
            )
        # Not the user's recording, and an unknown id: no context leaks.
        session.add(
            _ledger(
                account,
                entry_type="charge",
                amount=-1,
                balance_after=0,
                reference_type="recording",
                reference_id=str(foreign.id),
                created_at=T0 + timedelta(minutes=10),
            )
        )
        session.add(
            _ledger(
                account,
                entry_type="release",
                amount=0,
                balance_after=0,
                reference_type="recording",
                reference_id="not-a-uuid",
                created_at=T0 + timedelta(minutes=11),
            )
        )
        await session.commit()
        return user.id, {str(item.id): item.duration_seconds for item in recordings}

    user_id, durations = _run(settings, seed)
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: AuthPrincipal(
        user_id, uuid.uuid4(), "user", scopes_for_role("user")
    )
    statements: list[str] = []

    with TestClient(app, base_url="https://testserver") as client:
        engine = app.state.database.engine.sync_engine

        def count(_conn, _cursor, statement, *_args) -> None:
            if statement.lstrip().upper().startswith("SELECT"):
                statements.append(statement)

        event.listen(engine, "before_cursor_execute", count)
        try:
            response = client.get("/v1/credits/transactions", params={"limit": 50})
        finally:
            event.remove(engine, "before_cursor_execute", count)

    assert response.status_code == 200, response.text
    items = response.json()["items"]
    charged = {
        item["reference_id"]: item for item in items if item["reference_id"] in durations
    }
    assert len(charged) == 5
    for reference_id, item in charged.items():
        assert item["recording_channel_username"].startswith("creator")
        assert item["recording_duration_seconds"] == durations[reference_id]
        assert item["store_order_id"] is None
    others = [item for item in items if item["reference_id"] not in durations]
    assert len(others) == 2
    assert all(item["recording_channel_username"] is None for item in others)
    # One query for the page, one for the recordings (none for orders here),
    # not one per entry.
    ledger_selects = [s for s in statements if "credit_ledger_entries" in s]
    recording_selects = [s for s in statements if "FROM recordings" in s]
    assert len(ledger_selects) == 1
    assert len(recording_selects) == 1


# --- 4: Retry-After on reward 429s ----------------------------------------------


def test_reward_rate_limit_and_lock_report_retry_after(tmp_path) -> None:
    settings = replace(
        _settings(tmp_path, "rewards.db"),
        reward_provider="fake",
        admob_reward_ad_units=("ca-app-pub-1/2",),
        reward_intents_per_hour=2,
    )

    async def seed(session):
        user = await _user(session)
        service = RewardService(session, settings)
        request = CreateRewardRequest(purpose="cloud_minutes", device_id="install-1")
        first = await service.create(user.id, request)
        await service.create(user.id, request)
        # The oldest intent leaves the 1-hour window in 10 minutes.
        first.created_at = utcnow() - timedelta(minutes=50)
        await session.commit()
        with pytest.raises(ApplicationError) as limited:
            await service.create(user.id, request)
        assert limited.value.code == "RATE_LIMITED"
        assert limited.value.status_code == 429
        retry = limited.value.details["retry_after_seconds"]
        assert 590 <= retry <= 600
        assert limited.value.details["window_seconds"] == 3600
        assert limited.value.details["limit"] == 2

        # Once that intent is out of the window another may start.
        first.created_at = utcnow() - timedelta(minutes=61)
        await session.commit()
        await service.create(user.id, request)
        return user.id

    user_id = _run(settings, seed)
    with _client(settings, user_id) as client:
        response = client.post(
            "/v1/rewards", json={"purpose": "cloud_minutes", "device_id": "install-1"}
        )
        assert response.status_code == 429
        body = response.json()["error"]
        assert body["code"] == "RATE_LIMITED"
        retry = body["details"]["retry_after_seconds"]
        assert isinstance(retry, int) and 1 <= retry <= 3600
        assert response.headers["Retry-After"] == str(retry)

    async def lock(session) -> None:
        session.add(
            RewardUserState(
                user_id=user_id,
                invalid_streak=3,
                locked_until=utcnow() + timedelta(seconds=120),
            )
        )
        await session.commit()

    _run(settings, lock)
    with _client(settings, user_id) as client:
        response = client.post(
            "/v1/rewards", json={"purpose": "cloud_minutes", "device_id": "install-1"}
        )
        assert response.status_code == 429
        body = response.json()["error"]
        assert body["code"] == "REWARD_LOCKED"
        assert 110 <= body["details"]["retry_after_seconds"] <= 120
        assert "locked_until" in body["details"]
        assert response.headers["Retry-After"] == str(body["details"]["retry_after_seconds"])

        # Other errors carry no Retry-After.
        missing = client.get(f"/v1/rewards/{uuid.uuid4()}")
        assert missing.status_code == 404
        assert "Retry-After" not in missing.headers


def test_global_rate_limiter_429_sets_retry_after(tmp_path) -> None:
    settings = replace(
        _settings(tmp_path, "global.db"), api_rate_limit=1, api_rate_window_seconds=60
    )
    _run(settings, _user)
    app = create_app(settings)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        client.get("/v1/public/pricing")
        limited = client.get("/v1/public/pricing")
    assert limited.status_code == 429
    retry = limited.json()["error"]["details"]["retry_after_seconds"]
    assert limited.headers["Retry-After"] == str(retry)


# --- 5: featured pack ------------------------------------------------------------


def test_featured_pack_is_config_driven_and_prices_unchanged(tmp_path, monkeypatch) -> None:
    settings = _settings(tmp_path, "featured.db", featured_package_codes=("standard",))

    async def seed(session):
        user = await _user(session)
        session.add_all(_packages())
        await session.commit()
        return user.id

    user_id = _run(settings, seed)
    with _client(settings, user_id) as client:
        packages = client.get("/v1/billing/packages").json()["items"]
        public = client.get("/v1/public/pricing").json()["packages"]
    for items in (packages, public):
        flags = {item["name"]: item["featured"] for item in items}
        assert flags == {"Starter": False, "Standard": True, "Premium": False}
        prices = {item["name"]: item["price"]["amount_minor"] for item in items}
        assert prices == {"Starter": 999, "Standard": 2_499, "Premium": 5_999}

    plain = _settings(tmp_path, "featured.db")
    with _client(plain, user_id) as client:
        items = client.get("/v1/billing/packages").json()["items"]
    assert not any(item["featured"] for item in items)

    # Off by default outside staging/production; a list of codes when set.
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "local")
    monkeypatch.delenv("SAVESTREAM_FEATURED_PACKAGE_CODES", raising=False)
    assert AppSettings.from_env().featured_package_codes == ()
    monkeypatch.setenv("SAVESTREAM_FEATURED_PACKAGE_CODES", "standard, premium")
    assert AppSettings.from_env().featured_package_codes == ("standard", "premium")


def test_featured_defaults_to_standard_in_production(monkeypatch) -> None:
    from tests.test_phase14_release_readiness import _production_env

    _production_env(monkeypatch)
    monkeypatch.delenv("SAVESTREAM_FEATURED_PACKAGE_CODES", raising=False)
    assert AppSettings.from_env().featured_package_codes == ("standard",)
    monkeypatch.setenv("SAVESTREAM_FEATURED_PACKAGE_CODES", "")
    assert AppSettings.from_env().featured_package_codes == ()


def test_openapi_documents_the_new_fields(tmp_path) -> None:
    schemas = create_app(_settings(tmp_path, "openapi.db")).openapi()["components"]["schemas"]
    assert {"last_pack_name", "last_pack_minutes", "cloud_minutes_cycle_total", "trial_used"} <= set(
        schemas["EntitlementResponse"]["properties"]
    )
    assert {"store_order_id", "client_price_amount_micros", "client_price_currency"} <= set(
        schemas["PaymentOrderResponse"]["properties"]
    )
    assert {"price_amount_micros", "price_currency_code"} <= set(
        schemas["StorePurchaseRequest"]["properties"]
    )
    assert {
        "store_order_id",
        "package_name",
        "recording_channel_username",
        "recording_duration_seconds",
    } <= set(schemas["CreditTransactionResponse"]["properties"])
    assert "featured" in schemas["CreditPackageResponse"]["properties"]
    assert "featured" in schemas["PublicCreditPackage"]["properties"]
