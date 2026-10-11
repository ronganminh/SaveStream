from __future__ import annotations

import asyncio
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.models import SocialIdentity, User
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.infrastructure.security.firebase_identity import (
    FirebasePrincipal,
    FirebaseTokenVerifier,
)
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings, one_time_token


def _mock_identity(
    monkeypatch, *, uid="google-user-a", email="new@example.com",
    provider="google.com", verified=True,
):
    async def verify(self, token):
        assert token == "signed-test-firebase-id-token"
        return FirebasePrincipal(
            uid=uid,
            provider=provider,
            email=email,
            email_verified=verified,
            display_name="Person",
        )

    monkeypatch.setattr(FirebaseTokenVerifier, "verify", verify)


def _social(client, client_type="mobile"):
    return client.post(
        "/v1/auth/social",
        json={"id_token": "signed-test-firebase-id-token", "client_type": client_type},
    )


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _register_and_verify(client, settings, email):
    register = client.post(
        "/v1/auth/register",
        json={"email": email, "password": "strong-existing-password"},
    )
    assert register.status_code == 201
    token = one_time_token(settings, email, "verify_email")
    assert client.post("/v1/auth/verify-email", json={"token": token}).status_code == 200


def _count_users_and_grants(database_url):
    async def read():
        db = Database(database_url)
        try:
            async with db.session() as session:
                user_count = await session.scalar(select(func.count(User.id)))
                grant_count = await session.scalar(
                    select(func.count(CreditLedgerEntry.id)).where(
                        CreditLedgerEntry.reference_key.like("%signup%")
                    )
                )
                social_count = await session.scalar(select(func.count(SocialIdentity.firebase_uid)))
                return user_count, grant_count, social_count
        finally:
            await db.close()
    return asyncio.run(read())


def test_social_signup_reuses_identity_and_web_cookie(monkeypatch, tmp_path):
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'social.db'}"
    settings = replace(
        identity_settings(database_url), firebase_auth_project_id="test-firebase-project"
    )
    create_schema(database_url)
    app = create_app(settings)
    _mock_identity(monkeypatch)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        signup = _social(client)
        assert signup.status_code == 200, signup.text
        assert signup.json()["refresh_token"]
        first = client.get("/v1/me", headers=_auth(signup.json()["access_token"]))
        assert first.status_code == 200
        first_user_id = first.json()["id"]

        another_device = _social(client, "web")
        assert another_device.status_code == 200, another_device.text
        assert another_device.json()["refresh_token"] is None
        assert "httponly" in another_device.headers["set-cookie"].lower()
        assert "secure" in another_device.headers["set-cookie"].lower()
        assert (
            client.get("/v1/me", headers=_auth(another_device.json()["access_token"]))
            .json()["id"] == first_user_id
        )
    users, grants, identities = _count_users_and_grants(database_url)
    assert users == 1
    assert identities == 1
    assert grants == 1


def test_matching_email_does_not_auto_link(monkeypatch, tmp_path):
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'collision.db'}"
    settings = replace(
        identity_settings(database_url), firebase_auth_project_id="test-firebase-project"
    )
    create_schema(database_url)
    app = create_app(settings)
    _mock_identity(monkeypatch, email="existing@example.com", provider="apple.com")

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        _register_and_verify(client, settings, "existing@example.com")
        collision = _social(client)
        assert collision.status_code == 409
        assert collision.json()["error"]["code"] == "AUTH_ACCOUNT_LINK_REQUIRED"

        password_login = client.post(
            "/v1/auth/login",
            json={
                "email": "existing@example.com",
                "password": "strong-existing-password",
                "client_type": "mobile",
            },
        )
        assert password_login.status_code == 200
        user_id = client.get(
            "/v1/me", headers=_auth(password_login.json()["access_token"])
        ).json()["id"]

        wrong_password = client.post(
            "/v1/auth/social/link",
            json={"id_token": "signed-test-firebase-id-token", "password": "wrong"},
            headers=_auth(password_login.json()["access_token"]),
        )
        assert wrong_password.status_code == 401

        link = client.post(
            "/v1/auth/social/link",
            json={
                "id_token": "signed-test-firebase-id-token",
                "password": "strong-existing-password",
            },
            headers=_auth(password_login.json()["access_token"]),
        )
        assert link.status_code == 200, link.text
        linked_login = _social(client)
        assert linked_login.status_code == 200
        linked_id = client.get(
            "/v1/me", headers=_auth(linked_login.json()["access_token"])
        ).json()["id"]
        assert linked_id == user_id

    users, grants, identities = _count_users_and_grants(database_url)
    assert users == 1
    assert identities == 1
    assert grants == 1


def test_social_signup_requires_verified_email(monkeypatch, tmp_path):
    url = f"sqlite+aiosqlite:///{tmp_path / 'unverified.db'}"
    settings = replace(identity_settings(url), firebase_auth_project_id="demo-project")
    create_schema(url)
    _mock_identity(monkeypatch, verified=False)
    with TestClient(create_app(settings), base_url="https://testserver") as client:
        response = _social(client)
        assert response.status_code == 422
        assert response.json()["error"]["code"] == "AUTH_SOCIAL_EMAIL_REQUIRED"
    assert _count_users_and_grants(url)[0] == 0


def test_social_disabled_fails_closed(tmp_path):
    url = f"sqlite+aiosqlite:///{tmp_path / 'disabled.db'}"
    settings = identity_settings(url)
    create_schema(url)
    with TestClient(create_app(settings), base_url="https://testserver") as client:
        response = _social(client)
        assert response.status_code == 503
        assert response.json()["error"]["code"] == "SOCIAL_AUTH_NOT_CONFIGURED"


def test_verifier_rejects_wrong_firebase_issuer(monkeypatch):
    settings = replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        firebase_auth_project_id="save-project",
    )
    import app.infrastructure.security.firebase_identity as verifier_module

    def fake_claims(token, project):
        assert project == "save-project"
        return {
            "sub": "firebase-a",
            "aud": "save-project",
            "iss": "https://accounts.google.com",
            "firebase": {"sign_in_provider": "google.com"},
            "email": "someone@example.com",
            "email_verified": True,
        }

    monkeypatch.setattr(verifier_module, "_verify_signed_token", fake_claims)

    async def run():
        try:
            await FirebaseTokenVerifier(settings).verify("test.jwt.signed")
        except Exception as exc:
            assert getattr(exc, "code", None) == "AUTH_SOCIAL_INVALID_TOKEN"
        else:
            raise AssertionError("Wrong issuer accepted")

    asyncio.run(run())
