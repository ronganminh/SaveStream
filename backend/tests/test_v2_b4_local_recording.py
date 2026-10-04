from __future__ import annotations

import asyncio
import base64
import uuid
from dataclasses import replace
from datetime import timedelta
from types import SimpleNamespace

import httpx
import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from sqlalchemy import select

from app.api.schemas.local_recordings import (
    CreateLocalRecordingSessionRequest,
    CreateRewardRequest,
    FinishLocalRecordingSessionRequest,
)
from app.application.entitlements.service import EntitlementService
from app.application.local_recordings.service import (
    LocalRecordingService,
    utcnow,
)
from app.application.rewards.service import RewardService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.local_recording_models import (
    LocalDailyUsage,
    LocalRecordingSession,
    LocalSlotGrant,
)
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.rewards.admob import AdMobRewardVerifier
from app.infrastructure.rewards.fake import FakeRewardVerifier
from app.infrastructure.db.session import Database
from app.settings import AppSettings
from tests.credit_helpers import grant_test_credits
from tests.identity_helpers import identity_settings


async def _user(session, email: str) -> User:
    user = User(
        email=email,
        normalized_email=email.casefold(),
        role="user",
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


async def _paid_order(session, user: User) -> None:
    package = CreditPackage(
        code=f"b4-{uuid.uuid4().hex}",
        name="B4 package",
        credits=100,
        amount_minor=999,
        currency="USD",
        active=True,
    )
    session.add(package)
    await session.flush()
    session.add(
        PaymentOrder(
            user_id=user.id,
            package_id=package.id,
            status="paid",
            credits=100,
            amount_minor=999,
            currency="USD",
        )
    )
    await session.commit()


def test_b4_pro_local_recording_switch_controls_entitlement(tmp_path) -> None:
    async def run() -> None:
        base = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b4-local-switch.db'}"
        )
        database = Database(base.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                free = await _user(session, "b4-free@example.com")
                pro = await _user(session, "b4-pro@example.com")
                await _paid_order(session, pro)
                await grant_test_credits(session, pro.id, 100)

                unlimited = replace(
                    base,
                    pro_local_recording="unlimited",
                )
                free_snapshot = await EntitlementService(
                    session,
                    unlimited,
                ).get(free.id)
                pro_snapshot = await EntitlementService(
                    session,
                    unlimited,
                ).get(pro.id)
                assert free_snapshot.local.enabled is True
                assert free_snapshot.local.unlimited is False
                assert pro_snapshot.local.enabled is True
                assert pro_snapshot.local.unlimited is True

                disabled = replace(
                    base,
                    pro_local_recording="disabled",
                )
                free_disabled = await EntitlementService(
                    session,
                    disabled,
                ).get(free.id)
                pro_disabled = await EntitlementService(
                    session,
                    disabled,
                ).get(pro.id)
                assert free_disabled.local.enabled is True
                assert free_disabled.local.unlimited is False
                assert pro_disabled.local.enabled is False
                assert pro_disabled.local.unlimited is False
        finally:
            await database.close()

    asyncio.run(run())


def test_b4_pro_local_recording_setting_rejects_unknown_value(
    monkeypatch,
) -> None:
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "test")
    monkeypatch.setenv("SAVESTREAM_PRO_LOCAL_RECORDING", "maybe")
    with pytest.raises(
        ValueError,
        match="SAVESTREAM_PRO_LOCAL_RECORDING",
    ):
        AppSettings.from_env()



async def _watch(session, user: User, suffix: str) -> Watch:
    row = Watch(
        user_id=user.id,
        source_type="room_id",
        source_value=f"room-{suffix}",
        active_dedupe_key=uuid.uuid4().hex,
        status="active",
        live_status="live",
        auto_record=False,
    )
    session.add(row)
    await session.commit()
    await session.refresh(row)
    return row


def _fake_runtime():
    class Resolver:
        def live_status(self, source):
            return (
                SimpleNamespace(
                    username=f"creator-{source.value}",
                    room_id=source.value,
                ),
                True,
            )

    class Gateway:
        def get_live_url(self, room_id):
            return f"https://stream.test/{room_id}.flv"

    return SimpleNamespace(resolver=Resolver(), gateway=Gateway())


def test_b4_free_minutes_reward_verification_and_second_slot(
    tmp_path,
    monkeypatch,
) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'b4-flow.db'}"
            ),
            reward_provider="fake",
            free_local_daily_minutes=10,
            reward_daily_cap=8,
            reward_minutes=10,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            monkeypatch.setattr(
                "app.application.local_recordings.service.build_recording_runtime",
                lambda _: _fake_runtime(),
            )

            async with database.session() as session:
                user = await _user(session, "b4-flow@example.com")
                first_watch = await _watch(session, user, "one")
                second_watch = await _watch(session, user, "two")
                third_watch = await _watch(session, user, "three")
                local = LocalRecordingService(session, settings)
                rewards = RewardService(session, settings)
                verifier = FakeRewardVerifier()

                first = await local.start(
                    user.id,
                    CreateLocalRecordingSessionRequest(
                        watch_id=str(first_watch.id),
                        device_id="device-a",
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                assert first.granted_seconds == 600

                finish = FinishLocalRecordingSessionRequest(
                    recorded_seconds=61,
                    size_bytes=123,
                    end_reason="user_stopped",
                    status="completed",
                )
                await local.finish(user.id, str(first.session_id), finish)
                await local.finish(user.id, str(first.session_id), finish)

                usage = await session.scalar(
                    select(LocalDailyUsage).where(
                        LocalDailyUsage.user_id == user.id,
                    )
                )
                assert usage is not None
                assert usage.used_minutes == 2
                snapshot = await EntitlementService(session, settings).get(user.id)
                assert snapshot.local.minutes_remaining == 8

                slot_rewards = []
                for index in range(2):
                    reward = await rewards.create(
                        user.id,
                        CreateRewardRequest(purpose="local_slot"),
                    )
                    callback = await verifier.verify_callback(
                        (
                            f"custom_data={reward.id}"
                            f"&user_id={user.id}"
                            f"&transaction_id=slot-{index}"
                        ).encode()
                    )
                    await rewards.apply_callback(callback)
                    slot_rewards.append(reward)

                grant = await session.scalar(
                    select(LocalSlotGrant).where(
                        LocalSlotGrant.user_id == user.id,
                    )
                )
                assert grant is not None
                snapshot = await EntitlementService(session, settings).get(user.id)
                assert snapshot.local.max_concurrent_sessions == 2
                assert snapshot.local.second_slot_expires_at is not None

                one = await local.start(
                    user.id,
                    CreateLocalRecordingSessionRequest(
                        watch_id=str(first_watch.id),
                        device_id="device-a",
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                two = await local.start(
                    user.id,
                    CreateLocalRecordingSessionRequest(
                        watch_id=str(second_watch.id),
                        device_id="device-b",
                    ),
                    idempotency_key=str(uuid.uuid4()),
                )
                assert one.session_id != two.session_id

                with pytest.raises(ApplicationError) as third:
                    await local.start(
                        user.id,
                        CreateLocalRecordingSessionRequest(
                            watch_id=str(third_watch.id),
                            device_id="device-c",
                        ),
                        idempotency_key=str(uuid.uuid4()),
                    )
                assert third.value.code == "LOCAL_SLOT_BUSY"

                minutes_reward = await rewards.create(
                    user.id,
                    CreateRewardRequest(purpose="local_minutes"),
                )
                pending = await rewards.get(user.id, str(minutes_reward.id))
                assert pending.status == "pending"
                callback = await verifier.verify_callback(
                    (
                        f"custom_data={minutes_reward.id}"
                        f"&user_id={user.id}"
                        "&transaction_id=minutes-1"
                    ).encode()
                )
                await rewards.apply_callback(callback)
                valid = await rewards.get(user.id, str(minutes_reward.id))
                assert valid.status == "valid"

                before = (
                    await session.get(LocalRecordingSession, one.session_id)
                ).granted_seconds
                await local.extend(
                    user.id,
                    str(one.session_id),
                    reward_id=str(minutes_reward.id),
                )
                extended = await session.get(
                    LocalRecordingSession,
                    one.session_id,
                )
                assert extended is not None
                assert extended.granted_seconds == before + 600
        finally:
            await database.close()

    asyncio.run(run())


def test_b4_expired_free_lease_charges_full_grant(tmp_path) -> None:
    async def run() -> None:
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'b4-expiry.db'}"
            ),
            free_local_daily_minutes=10,
            local_lease_grace_seconds=60,
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = await _user(session, "b4-expiry@example.com")
                watch = await _watch(session, user, "expiry")
                started = utcnow() - timedelta(minutes=20)
                row = LocalRecordingSession(
                    user_id=user.id,
                    watch_id=watch.id,
                    device_id="device-expiry",
                    device_name="Expiry Device",
                    creator_username="creator-expiry",
                    status="active",
                    granted_seconds=600,
                    free_granted_seconds=600,
                    unlimited=False,
                    started_at=started,
                    lease_expires_at=started + timedelta(minutes=10),
                )
                session.add(row)
                await session.commit()

                closed = await LocalRecordingService(
                    session,
                    settings,
                ).close_expired(now=utcnow())
                assert closed == 1
                await session.refresh(row)
                assert row.status == "partial"
                assert row.recorded_seconds == 600

                usage = await session.scalar(
                    select(LocalDailyUsage).where(
                        LocalDailyUsage.user_id == user.id,
                    )
                )
                assert usage is not None
                assert usage.used_minutes == 10
        finally:
            await database.close()

    asyncio.run(run())



def test_b4_admob_verifier_uses_signed_raw_query_and_key_server() -> None:
    async def run() -> None:
        import app.infrastructure.rewards.admob as admob_module

        admob_module._KEY_CACHE = None
        private_key = ec.generate_private_key(ec.SECP256R1())
        public_pem = private_key.public_key().public_bytes(
            serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo,
        ).decode("ascii")
        reward_id = uuid.uuid4()
        user_id = uuid.uuid4()
        signed = (
            f"custom_data={reward_id}"
            "&reward_amount=1"
            "&reward_item=minute"
            "&timestamp=1"
            "&transaction_id=admob-1"
            f"&user_id={user_id}"
        ).encode()
        signature = private_key.sign(
            signed,
            ec.ECDSA(hashes.SHA256()),
        )
        encoded = base64.urlsafe_b64encode(signature).decode().rstrip("=")
        raw_query = signed + (
            f"&signature={encoded}&key_id=123"
        ).encode()

        def handler(request: httpx.Request) -> httpx.Response:
            assert str(request.url) == (
                "https://www.gstatic.com/admob/reward/verifier-keys.json"
            )
            return httpx.Response(
                200,
                json={
                    "keys": [
                        {
                            "keyId": 123,
                            "pem": public_pem,
                        }
                    ]
                },
            )

        settings = replace(
            identity_settings("sqlite+aiosqlite:///:memory:"),
            reward_provider="admob",
        )
        async with httpx.AsyncClient(
            transport=httpx.MockTransport(handler)
        ) as client:
            callback = await AdMobRewardVerifier(
                settings,
                client=client,
            ).verify_callback(raw_query)

        assert callback.valid is True
        assert callback.reward_id == reward_id
        assert callback.user_id == user_id
        assert callback.transaction_id == "admob-1"

    asyncio.run(run())
