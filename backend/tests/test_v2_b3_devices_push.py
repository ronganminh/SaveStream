from __future__ import annotations

import asyncio
import json
import uuid
from dataclasses import replace
from datetime import timedelta

import httpx
from Crypto.PublicKey import RSA
from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.schemas.recordings import Source
from app.application.notifications.push import (
    PushDeliveryService,
    PushMessage,
    PushTokenInvalid,
)
from app.application.notifications.service import ensure_creator_live_notification
from app.application.recordings.service import utcnow
from app.application.watches.scheduler import WatchLiveResult, WatchScheduler
from app.infrastructure.db.models import (
    AuthSession,
    Base,
    DeviceRegistration,
    User,
)
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.push.fcm import FcmPushSender
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings, one_time_token


def _auth(access_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access_token}"}


def _register_verify_login(
    client: TestClient,
    settings,
    email: str,
) -> str:
    password = "correct horse battery staple"
    assert client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "B3 User",
        },
    ).status_code == 201
    token = one_time_token(settings, email, "verify_email")
    assert client.post(
        "/v1/auth/verify-email",
        json={"token": token},
    ).status_code == 200
    login = client.post(
        "/v1/auth/login",
        json={
            "email": email,
            "password": password,
            "client_type": "mobile",
        },
    )
    assert login.status_code == 200
    return login.json()["access_token"]


def _login(client: TestClient, email: str) -> str:
    login = client.post(
        "/v1/auth/login",
        json={
            "email": email,
            "password": "correct horse battery staple",
            "client_type": "mobile",
        },
    )
    assert login.status_code == 200
    return login.json()["access_token"]


class LiveChecker:
    def __init__(self, room_id: str, *, is_live: bool) -> None:
        self.room_id = room_id
        self.is_live = is_live

    async def check(self, source: Source) -> WatchLiveResult:
        return WatchLiveResult(
            username=source.value,
            room_id=self.room_id,
            is_live=self.is_live,
        )


class FakePushSender:
    def __init__(self) -> None:
        self.sent: list[tuple[str, PushMessage]] = []

    async def send(self, push_token: str, message: PushMessage) -> None:
        if push_token == "bad-token":
            raise PushTokenInvalid(push_token)
        self.sent.append((push_token, message))


def test_v2_b3_device_registration_and_session_revoke_cleanup(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'b3-devices.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        email = "b3-devices@example.com"
        first = _register_verify_login(client, settings, email)
        second = _login(client, email)

        first_put = client.put(
            "/v1/me/devices/device-one",
            headers=_auth(first),
            json={
                "platform": "android",
                "push_token": "token-one",
                "device_name": "Pixel",
                "app_version": "2.0.0",
                "locale": "en",
            },
        )
        assert first_put.status_code == 204

        second_put = client.put(
            "/v1/me/devices/device-two",
            headers=_auth(second),
            json={
                "platform": "ios",
                "push_token": None,
                "device_name": "iPhone",
                "app_version": "2.0.0",
                "locale": "vi",
            },
        )
        assert second_put.status_code == 204

        sessions = client.get("/v1/me/sessions", headers=_auth(second))
        assert sessions.status_code == 200
        non_current = next(
            item for item in sessions.json()["items"] if not item["current"]
        )
        revoked = client.delete(
            f"/v1/me/sessions/{non_current['id']}",
            headers=_auth(second),
        )
        assert revoked.status_code == 204

        async def assert_only_second() -> None:
            database = Database(database_url)
            try:
                async with database.session() as session:
                    rows = list(
                        (
                            await session.scalars(
                                select(DeviceRegistration).order_by(
                                    DeviceRegistration.device_id
                                )
                            )
                        ).all()
                    )
                    assert [row.device_id for row in rows] == ["device-two"]
                    assert rows[0].push_token is None
            finally:
                await database.close()

        asyncio.run(assert_only_second())

        deleted = client.delete(
            "/v1/me/devices/device-two",
            headers=_auth(second),
        )
        assert deleted.status_code == 204

        third_put = client.put(
            "/v1/me/devices/device-three",
            headers=_auth(second),
            json={
                "platform": "android",
                "push_token": "token-three",
                "device_name": "Pixel 2",
                "app_version": "2.0.1",
                "locale": "en",
            },
        )
        assert third_put.status_code == 204
        assert client.post(
            "/v1/auth/logout",
            headers=_auth(second),
        ).status_code == 204

        async def assert_none() -> None:
            database = Database(database_url)
            try:
                async with database.session() as session:
                    assert (
                        await session.scalar(
                            select(DeviceRegistration).limit(1)
                        )
                        is None
                    )
            finally:
                await database.close()

        asyncio.run(assert_none())


def test_v2_b3_creator_live_dedupe_and_switches(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'b3-live.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        email = "b3-live@example.com"
        token = _register_verify_login(client, settings, email)

        created = client.post(
            "/v1/watches",
            headers=_auth(token),
            json={
                "source": {"type": "username", "value": "creator-live"},
                "auto_record": False,
                "notify_on_live": True,
            },
        )
        assert created.status_code == 201
        watch_id = created.json()["id"]
        assert created.json()["notify_on_live"] is True

        async def drive(is_live: bool) -> None:
            database = Database(database_url)
            try:
                async with database.session() as session:
                    watch = await session.get(Watch, uuid.UUID(watch_id))
                    assert watch is not None
                    watch.next_check_at = utcnow() - timedelta(seconds=1)
                    await session.commit()
                    scheduler = WatchScheduler(
                        session,
                        settings,
                        random_fn=lambda: 0.5,
                    )
                    claim = next(
                        item
                        for item in await scheduler.claim_due()
                        if str(item.watch_id) == watch_id
                    )
                    await scheduler.process_claim(
                        claim,
                        LiveChecker("room-live", is_live=is_live),
                    )
            finally:
                await database.close()

        asyncio.run(drive(True))
        asyncio.run(drive(True))

        notifications = client.get(
            "/v1/notifications",
            headers=_auth(token),
        )
        assert notifications.status_code == 200
        live_items = [
            item
            for item in notifications.json()["items"]
            if item["type"] == "creator_live"
        ]
        assert len(live_items) == 1
        assert live_items[0]["resource_type"] == "watch"
        assert live_items[0]["resource_id"] == watch_id

        assert client.patch(
            f"/v1/watches/{watch_id}",
            headers=_auth(token),
            json={"notify_on_live": False},
        ).status_code == 200
        asyncio.run(drive(False))
        asyncio.run(drive(True))
        notifications = client.get("/v1/notifications", headers=_auth(token))
        assert len(
            [
                item
                for item in notifications.json()["items"]
                if item["type"] == "creator_live"
            ]
        ) == 1

        assert client.patch(
            f"/v1/watches/{watch_id}",
            headers=_auth(token),
            json={"notify_on_live": True},
        ).status_code == 200
        preferences = client.patch(
            "/v1/me/notification-preferences",
            headers=_auth(token),
            json={"creator_live": False},
        )
        assert preferences.status_code == 200
        assert preferences.json()["creator_live"] is False
        asyncio.run(drive(False))
        asyncio.run(drive(True))
        notifications = client.get("/v1/notifications", headers=_auth(token))
        assert len(
            [
                item
                for item in notifications.json()["items"]
                if item["type"] == "creator_live"
            ]
        ) == 1


def test_v2_b3_fake_push_sender_localizes_and_removes_invalid_token(
    tmp_path,
) -> None:
    async def run() -> None:
        settings = identity_settings(
            f"sqlite+aiosqlite:///{tmp_path / 'b3-push.db'}"
        )
        database = Database(settings.database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="push@example.com",
                    normalized_email="push@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.flush()
                auth_session = AuthSession(
                    user_id=user.id,
                    token_family_id=uuid.uuid4(),
                    client_type="mobile",
                    refresh_token_hash="hash",
                    refresh_history=[],
                    expires_at=utcnow() + timedelta(days=1),
                )
                session.add(auth_session)
                await session.flush()
                watch = Watch(
                    user_id=user.id,
                    source_type="username",
                    source_value="localized",
                    active_dedupe_key=uuid.uuid4().hex,
                    resolved_username="localized",
                    status="active",
                    live_status="live",
                    auto_record=False,
                    notify_on_live=True,
                    next_check_at=utcnow(),
                )
                session.add(watch)
                session.add_all(
                    [
                        DeviceRegistration(
                            user_id=user.id,
                            session_id=auth_session.id,
                            device_id="en-device",
                            platform="android",
                            push_token="en-token",
                            device_name="Pixel",
                            app_version="2.0.0",
                            locale="en-US",
                        ),
                        DeviceRegistration(
                            user_id=user.id,
                            session_id=auth_session.id,
                            device_id="vi-device",
                            platform="ios",
                            push_token="vi-token",
                            device_name="iPhone",
                            app_version="2.0.0",
                            locale="vi",
                        ),
                        DeviceRegistration(
                            user_id=user.id,
                            session_id=auth_session.id,
                            device_id="bad-device",
                            platform="android",
                            push_token="bad-token",
                            device_name="Bad",
                            app_version="2.0.0",
                            locale="en",
                        ),
                    ]
                )
                await session.flush()
                notification = await ensure_creator_live_notification(
                    session,
                    watch,
                    live_session_id=uuid.uuid4(),
                )
                assert notification is not None
                notification_id = str(notification.id)
                watch_id = str(watch.id)
                await session.commit()

                sender = FakePushSender()
                sent = await PushDeliveryService(session, sender).deliver(
                    notification_id
                )
                assert sent == 2
                by_token = {token: message for token, message in sender.sent}
                assert by_token["en-token"].title == "Creator is LIVE"
                assert by_token["vi-token"].title == "Kênh đang LIVE"
                assert by_token["vi-token"].data["resource_type"] == "watch"
                assert by_token["vi-token"].data["resource_id"] == watch_id

                bad = await session.scalar(
                    select(DeviceRegistration).where(
                        DeviceRegistration.device_id == "bad-device"
                    )
                )
                assert bad is not None
                assert bad.push_token is None
        finally:
            await database.close()

    asyncio.run(run())


def test_v2_b3_fcm_http_v1_sender_works_with_fake_server(tmp_path) -> None:
    async def run() -> None:
        key = RSA.generate(1024)
        service_account = {
            "project_id": "project-test",
            "client_email": "push@example.test",
            "private_key": key.export_key().decode("utf-8"),
            "token_uri": "https://oauth.test/token",
        }
        settings = replace(
            identity_settings(
                f"sqlite+aiosqlite:///{tmp_path / 'b3-fcm.db'}"
            ),
            push_provider="fcm",
            push_fcm_service_account_json=json.dumps(service_account),
            push_fcm_base_url="https://fcm.test",
            push_fcm_token_url="https://oauth.test/token",
        )
        seen: list[str] = []

        def handler(request: httpx.Request) -> httpx.Response:
            if request.url.host == "oauth.test":
                seen.append("oauth")
                assert request.method == "POST"
                return httpx.Response(
                    200,
                    json={"access_token": "access-token", "expires_in": 3600},
                )
            seen.append("send")
            assert request.url.path == (
                "/v1/projects/project-test/messages:send"
            )
            assert request.headers["authorization"] == "Bearer access-token"
            body = json.loads(request.content.decode("utf-8"))
            assert body["message"]["token"] == "fcm-device-token"
            assert body["message"]["data"]["resource_type"] == "watch"
            assert (
                body["message"]["android"]["notification"]["channel_id"]
                == "savestream_creator_live"
            )
            return httpx.Response(
                200,
                json={"name": "projects/project-test/messages/1"},
            )

        sender = FcmPushSender(
            settings,
            transport=httpx.MockTransport(handler),
        )
        await sender.send(
            "fcm-device-token",
            PushMessage(
                title="Creator is LIVE",
                body="@creator is LIVE now.",
                data={
                    "type": "creator_live",
                    "resource_type": "watch",
                    "resource_id": "watch-1",
                },
            ),
        )
        assert seen == ["oauth", "send"]

    asyncio.run(run())


def test_v2_b3_runtime_openapi_exposes_implemented_contract(tmp_path) -> None:
    settings = identity_settings(
        f"sqlite+aiosqlite:///{tmp_path / 'b3-openapi.db'}"
    )
    generated = create_app(settings).openapi()

    devices = generated["paths"]["/v1/me/devices/{device_id}"]
    assert devices["put"]["operationId"] == "upsertDevice"
    assert devices["delete"]["operationId"] == "deleteDevice"

    watch = generated["components"]["schemas"]["WatchResponse"]
    assert "notify_on_live" in watch["properties"]

    preferences = generated["components"]["schemas"][
        "NotificationPreferenceResponse"
    ]["properties"]
    assert preferences["creator_live"]["default"] is True
    assert preferences["recording_expiring"]["default"] is True
    assert preferences["free_minutes_low"]["default"] is True
    assert preferences["marketing"]["default"] is False

    notification = generated["components"]["schemas"]["NotificationResponse"]
    assert "watch" in notification["properties"]["resource_type"]["anyOf"][0]["enum"]
