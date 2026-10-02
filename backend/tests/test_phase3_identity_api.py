from __future__ import annotations

from fastapi.testclient import TestClient

from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings, one_time_token


def _auth(access_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access_token}"}


def _register_verify(
    client: TestClient,
    settings,
    email: str,
    password: str = "correct horse battery staple",
) -> None:
    response = client.post(
        "/v1/auth/register",
        json={"email": email, "password": password, "display_name": "Tester"},
    )
    assert response.status_code == 201
    token = one_time_token(settings, email, "verify_email")
    verified = client.post("/v1/auth/verify-email", json={"token": token})
    assert verified.status_code == 200


def test_identity_happy_path_refresh_reuse_and_web_cookie(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'identity.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()

        first = client.post(
            "/v1/auth/register",
            json={
                "email": "User@Example.com",
                "password": "correct horse battery staple",
                "display_name": "User",
            },
        )
        duplicate = client.post(
            "/v1/auth/register",
            json={
                "email": "user@example.com",
                "password": "another secure password",
                "display_name": "Someone",
            },
        )
        assert first.status_code == duplicate.status_code == 201
        assert first.json() == duplicate.json()

        verify_token = one_time_token(settings, "user@example.com", "verify_email")
        assert client.post(
            "/v1/auth/verify-email", json={"token": verify_token}
        ).status_code == 200

        login = client.post(
            "/v1/auth/login",
            json={
                "email": "user@example.com",
                "password": "correct horse battery staple",
                "client_type": "mobile",
            },
        )
        assert login.status_code == 200
        mobile = login.json()
        assert mobile["refresh_token"]
        me = client.get("/v1/me", headers=_auth(mobile["access_token"]))
        assert me.status_code == 200
        assert me.json()["role"] == "user"

        old_refresh = mobile["refresh_token"]
        rotated = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": old_refresh},
        )
        assert rotated.status_code == 200
        assert rotated.json()["refresh_token"] != old_refresh

        reused = client.post(
            "/v1/auth/refresh",
            json={"refresh_token": old_refresh},
        )
        assert reused.status_code == 401
        assert reused.json()["error"]["code"] == "AUTH_SESSION_REVOKED"
        assert client.get(
            "/v1/me",
            headers=_auth(rotated.json()["access_token"]),
        ).status_code == 401

        web_login = client.post(
            "/v1/auth/login",
            json={
                "email": "user@example.com",
                "password": "correct horse battery staple",
                "client_type": "web",
            },
        )
        assert web_login.status_code == 200
        assert web_login.json()["refresh_token"] is None
        cookie = web_login.headers["set-cookie"].lower()
        assert "secure" in cookie
        assert "httponly" in cookie
        assert "samesite=lax" in cookie

        web_refresh = client.post("/v1/auth/refresh", json={})
        assert web_refresh.status_code == 200
        assert web_refresh.json()["refresh_token"] is None

        sessions = client.get(
            "/v1/me/sessions",
            headers=_auth(web_refresh.json()["access_token"]),
        )
        assert sessions.status_code == 200
        assert any(item["current"] for item in sessions.json()["items"])


def test_password_reset_revokes_existing_sessions(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'reset.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        _register_verify(client, settings, "reset@example.com", "old-password-123")

        login = client.post(
            "/v1/auth/login",
            json={
                "email": "reset@example.com",
                "password": "old-password-123",
                "client_type": "mobile",
            },
        ).json()

        forgot = client.post(
            "/v1/auth/forgot-password",
            json={"email": "reset@example.com"},
        )
        assert forgot.status_code == 200
        reset_token = one_time_token(settings, "reset@example.com", "password_reset")
        reset = client.post(
            "/v1/auth/reset-password",
            json={"token": reset_token, "password": "new-password-456"},
        )
        assert reset.status_code == 200

        assert client.get("/v1/me", headers=_auth(login["access_token"])).status_code == 401
        old_login = client.post(
            "/v1/auth/login",
            json={
                "email": "reset@example.com",
                "password": "old-password-123",
                "client_type": "mobile",
            },
        )
        assert old_login.status_code == 401
        new_login = client.post(
            "/v1/auth/login",
            json={
                "email": "reset@example.com",
                "password": "new-password-456",
                "client_type": "mobile",
            },
        )
        assert new_login.status_code == 200
