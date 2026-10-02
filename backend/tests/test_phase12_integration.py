from __future__ import annotations

import asyncio
import uuid
from datetime import timedelta

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.dependencies import get_current_principal
from app.application.recordings.service import utcnow
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import AuthSession, Base, User
from app.infrastructure.db.recording_models import Recording, RecordingEvent
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.infrastructure.security.tokens import TokenService
from app.main import create_app
from tests.credit_helpers import configure_test_pricing, grant_test_credits
from tests.identity_helpers import create_schema, identity_settings, one_time_token


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _verified_login(client: TestClient, settings, email: str) -> dict:
    password = "phase12-secure-password"
    assert client.post(
        "/v1/auth/register",
        json={"email": email, "password": password, "display_name": "Phase 12"},
    ).status_code == 201
    token = one_time_token(settings, email, "verify_email")
    assert client.post(
        "/v1/auth/verify-email",
        json={"token": token},
    ).status_code == 200
    response = client.post(
        "/v1/auth/login",
        json={"email": email, "password": password, "client_type": "mobile"},
    )
    assert response.status_code == 200
    return response.json()


def test_phase12_auth_expiry_401_and_admin_403(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase12-auth.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()

        unauthenticated = client.get("/v1/me")
        assert unauthenticated.status_code == 401
        assert unauthenticated.json()["error"]["code"] == "AUTH_SESSION_REVOKED"

        login = _verified_login(client, settings, "phase12-auth@example.com")
        access_token = login["access_token"]

        forbidden = client.get(
            "/v1/admin/users",
            headers=_auth(access_token),
        )
        assert forbidden.status_code == 403
        assert forbidden.json()["error"]["code"] == "FORBIDDEN"

        claims = TokenService(settings).decode_access_token(access_token)

        async def expire_session() -> None:
            database = Database(database_url)
            try:
                async with database.session() as session:
                    auth_session = await session.get(AuthSession, claims.session_id)
                    assert auth_session is not None
                    auth_session.expires_at = utcnow() - timedelta(seconds=1)
                    await session.commit()
            finally:
                await database.close()

        asyncio.run(expire_session())

        expired = client.get("/v1/me", headers=_auth(access_token))
        assert expired.status_code == 401
        assert expired.json()["error"]["code"] == "AUTH_SESSION_REVOKED"


def test_phase12_idempotency_cursor_pagination_and_sse_resume(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'phase12-recordings.db'}"
    settings = identity_settings(database_url)

    async def seed() -> AuthPrincipal:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            async with database.session() as session:
                user = User(
                    email="phase12-recordings@example.com",
                    normalized_email="phase12-recordings@example.com",
                    role="user",
                    email_verified_at=utcnow(),
                )
                session.add(user)
                await session.commit()
                await session.refresh(user)
                await configure_test_pricing(session)
                await grant_test_credits(session, user.id, 100)
                return AuthPrincipal(
                    user.id,
                    uuid.uuid4(),
                    "user",
                    scopes_for_role("user"),
                )
        finally:
            await database.close()

    principal = asyncio.run(seed())
    app = create_app(settings)
    app.dependency_overrides[get_current_principal] = lambda: principal

    payload = {
        "source": {"type": "username", "value": "phase12-primary"},
        "max_duration_seconds": 60,
        "quality": "best",
        "container": "mp4",
    }
    idempotency_key = str(uuid.uuid4())

    with TestClient(app, base_url="https://testserver") as client:
        first = client.post(
            "/v1/recordings",
            headers={"Idempotency-Key": idempotency_key},
            json=payload,
        )
        assert first.status_code == 202
        replay = client.post(
            "/v1/recordings",
            headers={"Idempotency-Key": idempotency_key},
            json=payload,
        )
        assert replay.status_code == 202
        assert replay.json()["id"] == first.json()["id"]

        changed = client.post(
            "/v1/recordings",
            headers={"Idempotency-Key": idempotency_key},
            json={
                **payload,
                "source": {"type": "username", "value": "phase12-changed"},
            },
        )
        assert changed.status_code == 409
        assert changed.json()["error"]["code"] == "IDEMPOTENCY_KEY_REUSED"

        async def make_terminal_history() -> tuple[str, str, str]:
            database = Database(database_url)
            try:
                async with database.session() as session:
                    primary = await session.get(
                        Recording,
                        uuid.UUID(first.json()["id"]),
                    )
                    assert primary is not None
                    primary.status = "completed"
                    primary.active_dedupe_key = None
                    primary.actual_cost = 1
                    primary.ended_at = utcnow()

                    first_event = await session.scalar(
                        select(RecordingEvent)
                        .where(RecordingEvent.recording_id == primary.id)
                        .order_by(RecordingEvent.sequence)
                        .limit(1)
                    )
                    assert first_event is not None
                    started = RecordingEvent(
                        recording_id=primary.id,
                        sequence=2,
                        event_type="recording.started",
                        data={
                            "status": "recording",
                            "duration_seconds": 1,
                            "bytes_recorded": 10,
                        },
                    )
                    completed = RecordingEvent(
                        recording_id=primary.id,
                        sequence=3,
                        event_type="recording.completed",
                        data={
                            "status": "completed",
                            "duration_seconds": 2,
                            "bytes_recorded": 20,
                        },
                    )
                    extra_one = Recording(
                        user_id=principal.user_id,
                        source_type="username",
                        source_value="phase12-extra-one",
                        status="completed",
                        active_dedupe_key=None,
                        duration_seconds=1,
                        bytes_recorded=1,
                        estimated_max_cost=0,
                        actual_cost=0,
                        created_at=utcnow() - timedelta(minutes=1),
                        ended_at=utcnow() - timedelta(minutes=1),
                    )
                    extra_two = Recording(
                        user_id=principal.user_id,
                        source_type="username",
                        source_value="phase12-extra-two",
                        status="completed",
                        active_dedupe_key=None,
                        duration_seconds=1,
                        bytes_recorded=1,
                        estimated_max_cost=0,
                        actual_cost=0,
                        created_at=utcnow() - timedelta(minutes=2),
                        ended_at=utcnow() - timedelta(minutes=2),
                    )
                    session.add_all([started, completed, extra_one, extra_two])
                    await session.commit()
                    await session.refresh(started)
                    await session.refresh(completed)
                    return str(first_event.id), str(started.id), str(completed.id)
            finally:
                await database.close()

        first_event_id, started_id, completed_id = asyncio.run(
            make_terminal_history()
        )

        page_one = client.get("/v1/recordings?limit=2")
        assert page_one.status_code == 200
        first_payload = page_one.json()
        assert len(first_payload["items"]) == 2
        assert first_payload["pagination"]["has_more"] is True
        assert first_payload["pagination"]["next_cursor"]

        page_two = client.get(
            "/v1/recordings",
            params={
                "limit": 2,
                "cursor": first_payload["pagination"]["next_cursor"],
            },
        )
        assert page_two.status_code == 200
        second_payload = page_two.json()
        first_ids = {item["id"] for item in first_payload["items"]}
        second_ids = {item["id"] for item in second_payload["items"]}
        assert first_ids.isdisjoint(second_ids)
        assert len(first_ids | second_ids) == 3

        with client.stream(
            "GET",
            f"/v1/recordings/{first.json()['id']}/events",
            headers={"Last-Event-ID": started_id},
        ) as response:
            assert response.status_code == 200
            body = "".join(response.iter_text())

        assert f"id: {completed_id}" in body
        assert f"id: {first_event_id}" not in body
        assert f"id: {started_id}" not in body
        assert "recording.completed" in body

        invalid_cursor = client.get(
            "/v1/recordings",
            params={"cursor": "not-a-valid-cursor"},
        )
        assert invalid_cursor.status_code == 400
        assert invalid_cursor.json()["error"]["code"] == "VALIDATION_ERROR"
