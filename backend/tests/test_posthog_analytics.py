"""PostHog funnel events sent by the server (owner-approved 2026-10-21).

purchase_completed (PayPal capture or webhook) and first_recording_started /
first_recording_ready (recorder worker) go through the outbox, once per order
or account, keyed by the internal user id, never for staff accounts, and a
PostHog failure never breaks the flow.
"""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

from sqlalchemy import select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.application import analytics
from app.application.billing.service import BillingAdminService, BillingService
from app.application.recordings.service import RecordingService, utcnow
from app.infrastructure.analytics import posthog_client
from app.infrastructure.db.models import Base, OutboxEvent, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.payments.paypal import PayPalPaymentProvider
from app.infrastructure.queue import tasks
from app.infrastructure.recording import worker
from app.infrastructure.recording.media_probe import MediaInfo
from app.infrastructure.recording.runtime import RecordingRuntime
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.test_paypal_checkout import _paypal_transport
from tests.test_paypal_checkout import _settings as _paypal_settings
from tests.test_recording_worker_heartbeat import _Engine, _Gateway, _Redis, _Resolver

KEY = "phc_test_public_key"


async def _analytics_payloads(session) -> list[dict]:
    rows = (
        await session.scalars(
            select(OutboxEvent)
            .where(OutboxEvent.topic == analytics.ANALYTICS_TOPIC)
            .order_by(OutboxEvent.occurred_at)
        )
    ).all()
    return [row.payload for row in rows]


# --- purchase_completed ------------------------------------------------------


def _capture_once_and_replay(
    tmp_path, monkeypatch, *, role: str, key: str
) -> tuple[list[dict], User]:
    settings = replace(
        _paypal_settings(f"sqlite+aiosqlite:///{tmp_path / f'{role}-{bool(key)}.db'}"),
        posthog_api_key=key,
    )
    # The payment processor reads the process settings, like production.
    monkeypatch.setattr(analytics, "get_app_settings", lambda: settings)

    async def run() -> tuple[list[dict], User]:
        calls: list[str] = []
        provider = PayPalPaymentProvider(settings, transport=_paypal_transport(calls))
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="buyer@example.com",
                    normalized_email="buyer@example.com",
                    role=role,
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                package = await BillingAdminService(session, provider).create_package(
                    code="starter-10h",
                    name="Starter",
                    credits=600,
                    amount_minor=999,
                    currency="USD",
                )
                service = BillingService(session, settings, provider)
                order = await service.create_order(
                    user_id=user.id,
                    package_id=str(package.id),
                    idempotency_key=str(uuid.uuid4()),
                )
                await service.checkout(
                    user_id=user.id,
                    payment_order_id=str(order.id),
                    return_url=f"https://testserver/billing/success?order_id={order.id}",
                    idempotency_key=str(uuid.uuid4()),
                )
                for _ in range(2):  # the return page and a retry/webhook
                    paid = await service.capture(
                        user_id=user.id,
                        payment_order_id=str(order.id),
                        provider_order_id="PAYPAL-ORDER-123",
                    )
                    assert paid.status == "paid"
                return await _analytics_payloads(session), user
        finally:
            await database.close()

    return asyncio.run(run())


def test_paypal_capture_queues_one_purchase_completed_without_pii(tmp_path, monkeypatch) -> None:
    payloads, user = _capture_once_and_replay(tmp_path, monkeypatch, role="user", key=KEY)

    assert len(payloads) == 1
    payload = payloads[0]
    assert payload["event"] == "purchase_completed"
    assert payload["distinct_id"] == str(user.id)
    properties = dict(payload["properties"])
    uuid.UUID(properties.pop("package_id"))
    assert properties == {
        "pack": "Starter",
        "pack_code": "starter-10h",
        "credits": 600,
        "revenue": 9.99,
        "currency": "USD",
        "provider": "paypal",
        "first_purchase": True,
        "source": "server",
    }
    assert "buyer@example.com" not in repr(payload)
    uuid.UUID(payload["uuid"])  # stable id so a retried task is not counted twice


def test_staff_purchases_and_disabled_analytics_queue_nothing(tmp_path, monkeypatch) -> None:
    for role in ("owner", "admin", "support", "finance"):
        payloads, _ = _capture_once_and_replay(tmp_path, monkeypatch, role=role, key=KEY)
        assert payloads == [], role
    payloads, _ = _capture_once_and_replay(tmp_path, monkeypatch, role="user", key="")
    assert payloads == []


# --- first_recording_started / first_recording_ready ---------------------------


def _run_two_recordings(tmp_path, monkeypatch, *, role: str) -> list[dict]:
    settings = replace(
        _paypal_settings(f"sqlite+aiosqlite:///{tmp_path / f'rec-{role}.db'}"),
        recording_temp_dir=str(tmp_path / "rec"),
        posthog_api_key=KEY,
    )

    class _Storage:
        def __init__(self, settings) -> None:
            del settings

        def upload_file(self, path, key, *, content_type) -> None:
            return None

    monkeypatch.setattr(
        worker,
        "build_recording_runtime",
        lambda _settings: RecordingRuntime(resolver=_Resolver(), gateway=_Gateway()),
    )
    monkeypatch.setattr(worker, "RecordingEngine", _Engine)
    monkeypatch.setattr(worker, "MinioStorageClient", _Storage)
    monkeypatch.setattr(worker, "SyncRedis", _Redis)
    monkeypatch.setattr(
        worker, "probe_media", lambda _path: MediaInfo(duration_ms=65_000, width=720, height=1280)
    )

    async def seed_user() -> uuid.UUID:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="creator-fan@example.com",
                    normalized_email="creator-fan@example.com",
                    role=role,
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session, credits_per_unit=1)
                await mark_test_user_paid(session, user.id)
                await grant_test_credits(session, user.id, 500)
                return user.id
        finally:
            await database.close()

    async def new_recording(user_id: uuid.UUID, room_id: str) -> uuid.UUID:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                recording = await RecordingService(session, settings).create_for_user(
                    user_id,
                    CreateRecordingRequest(
                        source=Source(type="room_id", value=room_id),
                        max_duration_seconds=120,
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                return recording.id
        finally:
            await database.close()

    async def read() -> list[dict]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                for recording_id in recording_ids:
                    row = await session.get(Recording, recording_id)
                    assert row is not None and row.status == "completed", row and row.status
                return await _analytics_payloads(session)
        finally:
            await database.close()

    user_id = asyncio.run(seed_user())
    recording_ids = []
    for room_id in ("7695803833239358", "7695803833239359"):
        recording_id = asyncio.run(new_recording(user_id, room_id))
        asyncio.run(worker._run_recording_job(recording_id, settings))
        recording_ids.append(recording_id)
    payloads = asyncio.run(read())
    for payload in payloads:
        assert payload["distinct_id"] == str(user_id)
        assert "creator-fan@example.com" not in repr(payload)
        assert "76958038332393" not in repr(payload)  # no source, room or link
    return payloads


def test_only_the_first_recording_sends_started_and_ready(tmp_path, monkeypatch) -> None:
    payloads = _run_two_recordings(tmp_path, monkeypatch, role="user")

    assert [p["event"] for p in payloads] == ["first_recording_started", "first_recording_ready"]
    ready = payloads[1]["properties"]
    assert ready["duration_seconds"] == 65
    assert ready["credits_charged"] == 2  # per started minute
    assert ready["source"] == "server"


def test_staff_recordings_send_nothing(tmp_path, monkeypatch) -> None:
    assert _run_two_recordings(tmp_path, monkeypatch, role="owner") == []


# --- delivery ------------------------------------------------------------------


def test_delivery_sends_with_the_stable_uuid_and_swallows_posthog_errors(monkeypatch) -> None:
    settings = replace(_paypal_settings(), posthog_api_key=KEY)
    sent: list[tuple] = []

    class _Client:
        def capture(self, event, **kwargs):
            sent.append((event, kwargs))

    class _Broken:
        def capture(self, event, **kwargs):
            raise ConnectionError("posthog is down")

    payload = {
        "event": "purchase_completed",
        "distinct_id": "user-1",
        "properties": {"pack": "starter-10h"},
        "uuid": "6f1c0f5e-3d1b-5b7e-9a51-0e7a4f5c2b10",
    }
    monkeypatch.setattr(posthog_client, "_client", lambda key, host: _Client())
    assert posthog_client.deliver_analytics_event(payload, settings) is True
    assert sent == [
        (
            "purchase_completed",
            {
                "distinct_id": "user-1",
                "properties": {"pack": "starter-10h"},
                "uuid": "6f1c0f5e-3d1b-5b7e-9a51-0e7a4f5c2b10",
            },
        )
    ]

    monkeypatch.setattr(posthog_client, "_client", lambda key, host: _Broken())
    assert posthog_client.deliver_analytics_event(payload, settings) is False  # no raise

    off = replace(settings, posthog_api_key="")
    assert posthog_client.deliver_analytics_event(payload, off) is False


def test_outbox_task_routes_analytics_events_to_posthog(monkeypatch) -> None:
    delivered: list[dict] = []
    monkeypatch.setattr(
        posthog_client, "deliver_analytics_event", lambda payload: delivered.append(payload)
    )
    payload = {"event": "first_recording_ready", "distinct_id": "user-1", "properties": {}}
    tasks.handle_outbox_event.run(event_id="e1", topic="analytics.capture", payload=payload)
    assert delivered == [payload]


def test_an_analytics_failure_never_fails_a_recording_or_a_payment(tmp_path, monkeypatch) -> None:
    async def broken(*args, **kwargs):
        raise RuntimeError("analytics write failed")

    monkeypatch.setattr(analytics, "enqueue_analytics_event", broken)
    # Recordings still complete (asserted inside the helper) and nothing is queued.
    assert _run_two_recordings(tmp_path, monkeypatch, role="user") == []
    # The payment is still captured and credited.
    payloads, _ = _capture_once_and_replay(tmp_path, monkeypatch, role="user", key=KEY)
    assert payloads == []
