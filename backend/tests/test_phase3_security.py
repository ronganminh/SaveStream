from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from fastapi.testclient import TestClient

from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.infrastructure.security.tokens import TokenExpiredError, TokenService
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings, one_time_token


def _auth(access_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access_token}"}


def _verified_login(client, settings, email: str) -> dict:
    password = "secure-password-123"
    assert client.post(
        "/v1/auth/register",
        json={"email": email, "password": password},
    ).status_code == 201
    token = one_time_token(settings, email, "verify_email")
    assert client.post("/v1/auth/verify-email", json={"token": token}).status_code == 200
    response = client.post(
        "/v1/auth/login",
        json={"email": email, "password": password, "client_type": "mobile"},
    )
    assert response.status_code == 200
    return response.json()


def test_expired_access_token_is_rejected() -> None:
    settings = identity_settings("sqlite+aiosqlite:///:memory:")
    tokens = TokenService(settings)
    now = datetime.now(timezone.utc) - timedelta(seconds=10)
    import uuid

    token, _ = tokens.issue_access_token(
        user_id=uuid.uuid4(),
        session_id=uuid.uuid4(),
        now=now,
        ttl_seconds=1,
    )
    with pytest.raises(TokenExpiredError):
        tokens.decode_access_token(token)


def test_forgot_password_does_not_enumerate_accounts(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'enumeration.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        _verified_login(client, settings, "known@example.com")

        known = client.post(
            "/v1/auth/forgot-password",
            json={"email": "known@example.com"},
        )
        missing = client.post(
            "/v1/auth/forgot-password",
            json={"email": "missing@example.com"},
        )
        assert known.status_code == missing.status_code == 200
        assert known.json() == missing.json()


def test_cross_user_session_revoke_returns_not_found(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'cross-user.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        user_a = _verified_login(client, settings, "a@example.com")
        user_b = _verified_login(client, settings, "b@example.com")

        b_sessions = client.get(
            "/v1/me/sessions",
            headers=_auth(user_b["access_token"]),
        ).json()["items"]
        b_session_id = next(item["id"] for item in b_sessions if item["current"])

        forbidden = client.delete(
            f"/v1/me/sessions/{b_session_id}",
            headers=_auth(user_a["access_token"]),
        )
        assert forbidden.status_code == 404
        assert forbidden.json()["error"]["code"] == "RESOURCE_NOT_FOUND"


def test_login_brute_force_is_rate_limited(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'brute.db'}"
    settings = identity_settings(database_url, login_rate_limit=2)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        payload = {
            "email": "nobody@example.com",
            "password": "wrong-password",
            "client_type": "mobile",
        }
        assert client.post("/v1/auth/login", json=payload).status_code == 401
        assert client.post("/v1/auth/login", json=payload).status_code == 401
        limited = client.post("/v1/auth/login", json=payload)
        assert limited.status_code == 429
        assert limited.json()["error"]["code"] == "RATE_LIMITED"
