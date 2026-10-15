"""Terms/Privacy (18+) and Acceptable Use Policy acceptance evidence for new accounts."""

from __future__ import annotations

import asyncio
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.application.identity.legal import (
    CURRENT_AUP_VERSION,
    CURRENT_PRIVACY_VERSION,
    CURRENT_TERMS_VERSION,
)
from app.infrastructure.db.models import LegalConsent, User
from app.infrastructure.db.session import Database
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.infrastructure.security.firebase_identity import (
    FirebasePrincipal,
    FirebaseTokenVerifier,
)
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings

CONSENT = {
    "age_confirmed": True,
    "terms_version": CURRENT_TERMS_VERSION,
    "privacy_version": CURRENT_PRIVACY_VERSION,
    "aup_accepted": True,
    "aup_version": CURRENT_AUP_VERSION,
}


def _consents(database_url: str) -> list[tuple[str, LegalConsent]]:
    async def read():
        database = Database(database_url)
        try:
            async with database.session() as session:
                rows = await session.execute(
                    select(User.email, LegalConsent).join(
                        LegalConsent, LegalConsent.user_id == User.id
                    )
                )
                return [(email, consent) for email, consent in rows.all()]
        finally:
            await database.close()

    return asyncio.run(read())


def _user_count(database_url: str) -> int:
    async def read():
        database = Database(database_url)
        try:
            async with database.session() as session:
                return len(list((await session.scalars(select(User))).all()))
        finally:
            await database.close()

    return asyncio.run(read())


def test_web_signup_requires_and_records_consent(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'consent.db'}"
    settings = identity_settings(database_url)
    create_schema(database_url)
    app = create_app(settings)

    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        body = {"email": "web@example.com", "password": "strong-web-password", "client_type": "web"}

        missing = client.post("/v1/auth/register", json=body)
        assert missing.status_code == 428, missing.text
        assert missing.json()["error"]["code"] == "LEGAL_CONSENT_REQUIRED"
        assert missing.json()["error"]["details"]["terms_version"] == CURRENT_TERMS_VERSION

        not_adult = client.post(
            "/v1/auth/register", json={**body, "consent": {**CONSENT, "age_confirmed": False}}
        )
        assert not_adult.status_code == 400

        outdated = client.post(
            "/v1/auth/register",
            json={**body, "consent": {**CONSENT, "terms_version": "2026-10-05"}},
        )
        assert outdated.status_code == 409
        assert outdated.json()["error"]["code"] == "LEGAL_VERSION_OUTDATED"

        # The Acceptable Use confirmation is required too.
        no_aup = client.post(
            "/v1/auth/register",
            json={**body, "consent": {**CONSENT, "aup_accepted": False}},
        )
        assert no_aup.status_code == 428
        assert no_aup.json()["error"]["details"]["aup_version"] == CURRENT_AUP_VERSION
        old_aup = client.post(
            "/v1/auth/register",
            json={**body, "consent": {**CONSENT, "aup_version": "2026-01-01"}},
        )
        assert old_aup.status_code == 409
        assert _user_count(database_url) == 0

        created = client.post(
            "/v1/auth/register",
            json={**body, "consent": CONSENT},
            headers={"User-Agent": "consent-test-browser"},
        )
        assert created.status_code == 201, created.text

    rows = _consents(database_url)
    assert len(rows) == 1
    email, consent = rows[0]
    assert email == "web@example.com"
    assert consent.terms_version == CURRENT_TERMS_VERSION
    assert consent.privacy_version == CURRENT_PRIVACY_VERSION
    assert consent.age_confirmed is True
    assert consent.aup_accepted is True
    assert consent.aup_version == CURRENT_AUP_VERSION
    assert consent.method == "email_signup"
    assert consent.ip_address
    assert consent.user_agent == "consent-test-browser"
    assert consent.accepted_at is not None


def test_legacy_mobile_signup_without_consent_still_works(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'consent-mobile.db'}"
    create_schema(database_url)
    app = create_app(identity_settings(database_url))
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post(
            "/v1/auth/register",
            json={"email": "mobile@example.com", "password": "strong-mobile-password"},
        )
        assert response.status_code == 201
    assert _consents(database_url) == []


def test_new_web_social_account_requires_consent(monkeypatch, tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'consent-social.db'}"
    settings = replace(
        identity_settings(database_url), firebase_auth_project_id="test-firebase-project"
    )
    create_schema(database_url)

    async def verify(self, token):
        return FirebasePrincipal(
            uid="google-new-user",
            provider="google.com",
            email="social@example.com",
            email_verified=True,
            display_name="Social Person",
        )

    monkeypatch.setattr(FirebaseTokenVerifier, "verify", verify)
    app = create_app(settings)
    token = "signed-test-firebase-id-token"
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        first = client.post("/v1/auth/social", json={"id_token": token, "client_type": "web"})
        assert first.status_code == 428, first.text
        assert first.json()["error"]["code"] == "LEGAL_CONSENT_REQUIRED"
        assert _user_count(database_url) == 0

        without_aup = client.post(
            "/v1/auth/social",
            json={
                "id_token": token,
                "client_type": "web",
                "consent": {k: v for k, v in CONSENT.items() if not k.startswith("aup")},
            },
        )
        assert without_aup.status_code == 428
        assert _user_count(database_url) == 0

        accepted = client.post(
            "/v1/auth/social",
            json={"id_token": token, "client_type": "web", "consent": CONSENT},
        )
        assert accepted.status_code == 200, accepted.text

        # Returning user: no consent needed again.
        again = client.post("/v1/auth/social", json={"id_token": token, "client_type": "web"})
        assert again.status_code == 200, again.text

    rows = _consents(database_url)
    assert len(rows) == 1
    assert rows[0][1].method == "social_signup:google.com"
    assert rows[0][1].aup_accepted is True


def test_consent_ip_uses_forwarded_for_from_trusted_proxy(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'consent-ip.db'}"
    settings = replace(identity_settings(database_url), trusted_proxy_cidrs=("0.0.0.0/0",))
    create_schema(database_url)
    app = create_app(settings)
    with TestClient(app, base_url="https://testserver", client=("10.0.0.5", 50000)) as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        response = client.post(
            "/v1/auth/register",
            json={
                "email": "proxy@example.com",
                "password": "strong-proxy-password",
                "client_type": "web",
                "consent": CONSENT,
            },
            headers={"X-Forwarded-For": "203.0.113.7, 10.0.0.5"},
        )
        assert response.status_code == 201, response.text
    assert _consents(database_url)[0][1].ip_address == "203.0.113.7"
