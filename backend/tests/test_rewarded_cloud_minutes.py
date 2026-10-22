"""Rewarded ads that add cloud recording minutes (Android v2 plan §3.3):
+5 credits per verified SSV callback, 6 per UTC day per user and per
device, verified email only, ad unit allowlist, AdMob key rotation, the
entitlement `ads` block and the shared-device admin alert."""

from __future__ import annotations

import asyncio
import base64
import uuid
from dataclasses import replace

import httpx
import pytest
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from sqlalchemy import select

from app.api.schemas.local_recordings import CreateRewardRequest
from app.application.credits.service import CreditService
from app.application.entitlements.service import EntitlementService
from app.application.operations.service import OperationsService, evaluate_alerts
from app.application.recordings.service import utcnow
from app.application.rewards.ports import VerifiedRewardCallback
from app.application.rewards.service import RewardService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.local_recording_models import RewardIntent
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.rewards.admob import AdMobRewardVerifier
from tests.identity_helpers import identity_settings

DEVICE = "install-0001"


def _settings(tmp_path, name: str, **changes):
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}"),
        reward_provider="fake",
        **changes,
    )


async def _user(session, email: str, *, verified: bool = True) -> User:
    user = User(
        email=email,
        normalized_email=email,
        role="user",
        email_verified_at=utcnow() if verified else None,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


def _run(settings, body) -> None:
    async def wrapped() -> None:
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                await body(session)
        finally:
            await database.close()

    asyncio.run(wrapped())


def _callback(reward: RewardIntent, txn: str, **extra) -> VerifiedRewardCallback:
    return VerifiedRewardCallback(
        reward_id=reward.id,
        user_id=reward.user_id,
        transaction_id=txn,
        valid=extra.pop("valid", True),
        ad_unit=extra.pop("ad_unit", "ca-app-pub-1/2"),
        reward_amount=extra.pop("reward_amount", 5),
    )


async def _watch_ad(service: RewardService, user: User, txn: str, device: str = DEVICE):
    reward = await service.create(
        user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=device)
    )
    return await service.apply_callback(_callback(reward, txn))


def test_each_ad_adds_five_minutes_up_to_six_a_day(tmp_path) -> None:
    settings = _settings(tmp_path, "cap.db")

    async def body(session) -> None:
        user = await _user(session, "viewer@example.com")
        service = RewardService(session, settings)

        reward = await service.create(
            user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
        )
        assert reward.device_id == DEVICE
        assert (reward.expires_at.replace(tzinfo=None) - utcnow().replace(tzinfo=None)).total_seconds() <= 3600
        credited = await service.apply_callback(_callback(reward, "txn-0"))
        assert credited.status == "valid" and credited.credits_granted == 5
        assert (await CreditService(session).balance(user.id)).posted == 5

        # AdMob retries the same callback: no second grant.
        again = await service.apply_callback(_callback(reward, "txn-0"))
        assert again.status == "valid"
        assert (await CreditService(session).balance(user.id)).posted == 5
        grants = (
            await session.scalars(
                select(CreditLedgerEntry).where(CreditLedgerEntry.reference_type == "reward")
            )
        ).all()
        assert len(grants) == 1 and grants[0].amount == 5

        for index in range(1, 6):
            assert (await _watch_ad(service, user, f"txn-{index}")).status == "valid"
        assert (await CreditService(session).balance(user.id)).posted == 30
        with pytest.raises(ApplicationError) as capped:
            await service.create(
                user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
            )
        assert capped.value.code == "REWARD_DAILY_CAP_REACHED"
        assert "resets_at" in capped.value.details

        entitlement = await EntitlementService(session, settings).get(user.id)
        assert entitlement.ads is not None
        assert entitlement.ads.rewards_left_today == 0
        assert entitlement.ads.rewarded_available is False
        assert entitlement.ads.minutes_per_reward == 5

    _run(settings, body)


def test_device_cap_spans_accounts_and_shared_devices_alert(tmp_path) -> None:
    settings = _settings(tmp_path, "device.db", reward_cloud_device_daily_cap=6)

    async def body(session) -> None:
        service = RewardService(session, settings)
        users = [await _user(session, f"u{index}@example.com") for index in range(4)]
        for index in range(6):
            await _watch_ad(service, users[index % 3], f"d-{index}")
        # A fourth account on the same phone gets nothing more today.
        with pytest.raises(ApplicationError) as capped:
            await service.create(
                users[3].id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
            )
        assert capped.value.details["scope"] == "device"

        session.add(
            RewardIntent(
                user_id=users[3].id,
                purpose="cloud_minutes",
                status="pending",
                device_id=DEVICE,
                expires_at=utcnow(),
            )
        )
        await session.commit()
        snapshot = await OperationsService(session, settings).snapshot()
        assert snapshot.reward_shared_devices == 1
        assert "reward_shared_devices" in {a.code for a in evaluate_alerts(snapshot, settings)}

    _run(settings, body)


def test_unverified_email_missing_device_and_rate_limit(tmp_path) -> None:
    settings = _settings(tmp_path, "rules.db", reward_intents_per_hour=2)

    async def body(session) -> None:
        service = RewardService(session, settings)
        unverified = await _user(session, "new@example.com", verified=False)
        with pytest.raises(ApplicationError) as blocked:
            await service.create(
                unverified.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
            )
        assert blocked.value.code == "EMAIL_NOT_VERIFIED"
        entitlement = await EntitlementService(session, settings).get(unverified.id)
        assert entitlement.ads.rewarded_available is False
        assert entitlement.ads.show_banners is True

        user = await _user(session, "fast@example.com")
        with pytest.raises(ApplicationError):
            await service.create(user.id, CreateRewardRequest(purpose="cloud_minutes"))
        for _ in range(2):
            await service.create(
                user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
            )
        with pytest.raises(ApplicationError) as limited:
            await service.create(
                user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
            )
        assert limited.value.code == "RATE_LIMITED"

    _run(settings, body)


def test_forged_wrong_unit_wrong_amount_and_expired_callbacks(tmp_path) -> None:
    settings = _settings(tmp_path, "forged.db", admob_reward_ad_units=("ca-app-pub-1/2",))

    async def body(session) -> None:
        user = await _user(session, "careful@example.com")
        service = RewardService(session, settings)

        reward = await service.create(
            user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
        )
        # A bad signature leaves the real intent usable.
        forged = await service.apply_callback(_callback(reward, "forged", valid=False))
        assert forged.status == "pending" and forged.transaction_id is None
        assert (await service.apply_callback(_callback(reward, "real"))).status == "valid"

        wrong_unit = await service.create(
            user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
        )
        result = await service.apply_callback(
            _callback(wrong_unit, "unit", ad_unit="ca-app-pub-9/9")
        )
        assert result.status == "invalid"

        wrong_amount = await service.create(
            user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
        )
        result = await service.apply_callback(_callback(wrong_amount, "amount", reward_amount=50))
        assert result.status == "invalid"

        late = await service.create(
            user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
        )
        late.expires_at = utcnow()
        await session.commit()
        assert (await service.apply_callback(_callback(late, "late"))).status == "expired"

        # Replaying a used transaction id on another intent is refused.
        other = await service.create(
            user.id, CreateRewardRequest(purpose="cloud_minutes", device_id=DEVICE)
        )
        with pytest.raises(ApplicationError):
            await service.apply_callback(_callback(other, "real"))
        assert (await CreditService(session).balance(user.id)).posted == 5

    _run(settings, body)


def test_banners_stop_after_any_purchase_and_local_rewards_are_retired(tmp_path) -> None:
    settings = _settings(tmp_path, "banner.db", local_recording_enabled=False)

    async def body(session) -> None:
        user = await _user(session, "buyer@example.com")
        assert (await EntitlementService(session, settings).get(user.id)).ads.show_banners

        package = CreditPackage(
            code="starter", name="Starter", credits=3000, amount_minor=1149,
            currency="USD", active=True,
        )
        session.add(package)
        await session.flush()
        session.add(
            PaymentOrder(
                user_id=user.id, package_id=package.id, status="paid", credits=3000,
                amount_minor=1149, currency="USD", provider="google_play",
                provider_reference="token:x", paid_at=utcnow(),
            )
        )
        await session.commit()
        assert (await EntitlementService(session, settings).get(user.id)).ads.show_banners is False

        with pytest.raises(ApplicationError) as retired:
            await RewardService(session, settings).create(
                user.id, CreateRewardRequest(purpose="local_minutes")
            )
        assert retired.value.status_code == 410

    _run(settings, body)


def test_unknown_admob_key_refreshes_the_key_set() -> None:
    async def run() -> None:
        import app.infrastructure.rewards.admob as admob_module

        old_key = ec.generate_private_key(ec.SECP256R1())
        new_key = ec.generate_private_key(ec.SECP256R1())

        def pem(key) -> str:
            return key.public_key().public_bytes(
                serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
            ).decode()

        reward_id, user_id = uuid.uuid4(), uuid.uuid4()
        signed = (
            f"ad_network=1&ad_unit=ca-app-pub-1/2&custom_data={reward_id}"
            f"&reward_amount=5&reward_item=minutes&timestamp=1&transaction_id=t-1"
            f"&user_id={user_id}"
        ).encode()
        signature = base64.urlsafe_b64encode(
            new_key.sign(signed, ec.ECDSA(hashes.SHA256()))
        ).decode().rstrip("=")
        raw_query = signed + f"&signature={signature}&key_id=456".encode()

        served: list[int] = []

        def handler(_request: httpx.Request) -> httpx.Response:
            served.append(1)
            keys = [{"keyId": 123, "pem": pem(old_key)}]
            if len(served) > 1:
                keys.append({"keyId": 456, "pem": pem(new_key)})
            return httpx.Response(200, json={"keys": keys})

        settings = replace(
            identity_settings("sqlite+aiosqlite:///:memory:"), reward_provider="admob"
        )
        admob_module._KEY_CACHE = None
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            verifier = AdMobRewardVerifier(settings, client=client)
            await verifier._keys()  # cache holds only the old key
            callback = await verifier.verify_callback(raw_query)
        admob_module._KEY_CACHE = None

        assert callback.valid is True and len(served) == 2
        assert callback.ad_unit == "ca-app-pub-1/2" and callback.reward_amount == 5

    asyncio.run(run())
