from __future__ import annotations

import asyncio

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.application.recordings.service import append_event
from app.infrastructure.db.models import User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
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
    registered = client.post(
        "/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "display_name": "Notifier",
        },
    )
    assert registered.status_code == 201
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


def _second_login(client: TestClient, email: str) -> str:
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


def _seed_recording_events(
    database_url: str,
    email: str,
    *,
    suffix: str,
    duplicate_started: bool = False,
) -> str:
    async def run() -> str:
        database = Database(database_url)
        try:
            async with database.session() as session:
                user = await session.scalar(
                    select(User).where(User.normalized_email == email.casefold())
                )
                assert user is not None
                recording = Recording(
                    user_id=user.id,
                    source_type="username",
                    source_value=f"creator-{suffix}",
                    status="recording",
                )
                session.add(recording)
                await session.flush()
                await append_event(session, recording, "recording.started")
                if duplicate_started:
                    await append_event(session, recording, "recording.started")
                recording.status = "completed"
                await append_event(session, recording, "recording.completed")
                await session.commit()
                return str(recording.id)
        finally:
            await database.close()

    return asyncio.run(run())


def test_persisted_notifications_read_state_dedupe_and_preferences(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'notifications.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        email = "notify@example.com"
        first_token = _register_verify_login(client, settings, email)
        second_token = _second_login(client, email)

        first_recording_id = _seed_recording_events(
            database_url,
            email,
            suffix="one",
            duplicate_started=True,
        )

        first_list = client.get(
            "/v1/notifications",
            headers=_auth(first_token),
        )
        assert first_list.status_code == 200
        payload = first_list.json()
        assert len(payload["items"]) == 2
        assert {item["type"] for item in payload["items"]} == {
            "recording_started",
            "recording_ready",
        }
        assert all(item["resource_id"] == first_recording_id for item in payload["items"])
        assert all(not item["read"] for item in payload["items"])
        assert payload["pagination"] == {"next_cursor": None, "has_more": False}

        second_list = client.get(
            "/v1/notifications",
            headers=_auth(second_token),
        )
        assert second_list.status_code == 200
        assert {
            item["id"] for item in second_list.json()["items"]
        } == {
            item["id"] for item in payload["items"]
        }

        notification_id = payload["items"][0]["id"]
        marked = client.patch(
            f"/v1/notifications/{notification_id}",
            json={"read": True},
            headers=_auth(second_token),
        )
        assert marked.status_code == 200
        assert marked.json()["read"] is True

        unread = client.get(
            "/v1/notifications?unread_only=true",
            headers=_auth(first_token),
        )
        assert unread.status_code == 200
        assert len(unread.json()["items"]) == 1

        marked_all = client.post(
            "/v1/notifications/mark-all-read",
            headers=_auth(first_token),
        )
        assert marked_all.status_code == 200
        assert marked_all.json()["updated"] == 1

        preferences = client.get(
            "/v1/me/notification-preferences",
            headers=_auth(first_token),
        )
        assert preferences.status_code == 200
        assert preferences.json() == {
            "recording_started": True,
            "recording_ready": True,
            "recording_failed": True,
            "email_supported": False,
            "updated_at": None,
        }

        updated = client.patch(
            "/v1/me/notification-preferences",
            json={"recording_started": False},
            headers=_auth(first_token),
        )
        assert updated.status_code == 200
        assert updated.json()["recording_started"] is False
        assert updated.json()["recording_ready"] is True
        assert updated.json()["email_supported"] is False

        _seed_recording_events(
            database_url,
            email,
            suffix="two",
        )
        final_list = client.get(
            "/v1/notifications",
            headers=_auth(first_token),
        )
        assert final_list.status_code == 200
        types = [item["type"] for item in final_list.json()["items"]]
        assert types.count("recording_started") == 1
        assert types.count("recording_ready") == 2
