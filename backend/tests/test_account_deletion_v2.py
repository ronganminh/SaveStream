"""Account deletion for Google Play (Android v2 plan §3.4) and backend
cleanup for v2 (§3.6): public deletion link, full erasure of linked data,
retired on-device recording, mobile consent switch."""

from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import date

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from app.application.privacy.service import PrivacyService
from app.application.recordings.service import utcnow
from app.infrastructure.db.admin_models import AdminEmailLog, PartnerApplication
from app.infrastructure.db.local_recording_models import LocalDailyUsage
from app.infrastructure.db.models import (
    AuthSession,
    OneTimeToken,
    OutboxEvent,
    SocialIdentity,
    User,
)
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.notifications.email_delivery import send_account_deleted_email
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings, one_time_token

PASSWORD = "correct horse battery staple"


def _client(tmp_path, name: str, **changes):
    settings = replace(identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}"), **changes)
    create_schema(settings.database_url)
    app = create_app(settings)
    return settings, app


def _signed_up(client: TestClient, settings, email: str) -> str:
    assert client.post(
        "/v1/auth/register", json={"email": email, "password": PASSWORD}
    ).status_code == 201
    token = one_time_token(settings, email, "verify_email")
    assert client.post("/v1/auth/verify-email", json={"token": token}).status_code == 200
    login = client.post(
        "/v1/auth/login", json={"email": email, "password": PASSWORD, "client_type": "mobile"}
    )
    assert login.status_code == 200
    return login.json()["access_token"]


def _query(settings, run):
    async def wrapped():
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                return await run(session)
        finally:
            await database.close()

    return asyncio.run(wrapped())


def test_public_deletion_link_flow(tmp_path) -> None:
    settings, app = _client(tmp_path, "delete-link.db")
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        _signed_up(client, settings, "leaving@example.com")

        unknown = client.post(
            "/v1/auth/account-deletion/request", json={"email": "nobody@example.com"}
        )
        known = client.post(
            "/v1/auth/account-deletion/request", json={"email": "Leaving@Example.com"}
        )
        # Same answer either way: no account enumeration.
        assert unknown.status_code == known.status_code == 200
        assert unknown.json() == known.json()

        async def tokens(session):
            return (
                await session.scalars(
                    select(OneTimeToken.purpose).where(OneTimeToken.purpose == "account_deletion")
                )
            ).all()

        assert _query(settings, tokens) == ["account_deletion"]

        token = one_time_token(settings, "leaving@example.com", "account_deletion")
        bad = client.post("/v1/auth/account-deletion/confirm", json={"token": "x" * 40})
        assert bad.status_code in (400, 401)
        confirmed = client.post("/v1/auth/account-deletion/confirm", json={"token": token})
        assert confirmed.status_code == 202
        reused = client.post("/v1/auth/account-deletion/confirm", json={"token": token})
        assert reused.status_code == 400

        async def state(session):
            user = await session.scalar(select(User))
            active_sessions = await session.scalar(
                select(func.count())
                .select_from(AuthSession)
                .where(AuthSession.revoked_at.is_(None))
            )
            topics = (await session.scalars(select(OutboxEvent))).all()
            return user, active_sessions, topics

        user, active_sessions, events = _query(settings, state)
        assert user.is_active is False and user.deletion_requested_at is not None
        assert active_sessions == 0
        deletion = [e for e in events if e.topic == "identity.account_deletion_requested"]
        assert deletion and deletion[0].payload["email"] == "leaving@example.com"
        assert any(e.topic == "identity.email.account_deletion" for e in events)
        # A deleted account can't ask for another link.
        again = client.post(
            "/v1/auth/account-deletion/request", json={"email": "leaving@example.com"}
        )
        assert again.status_code == 200
        assert len(_query(settings, tokens)) == 1


def test_erasure_covers_social_login_partner_and_email_logs(tmp_path) -> None:
    settings, app = _client(tmp_path, "erase.db")
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        _signed_up(client, settings, "creator@example.com")

    async def seed_and_erase(session):
        user = await session.scalar(select(User))
        session.add(SocialIdentity(firebase_uid="firebase-uid-1", user_id=user.id, provider="google.com"))
        session.add(
            Watch(
                user_id=user.id,
                source_type="username",
                source_value="my.channel",
                resolved_username="my.channel",
                creator_display_name="My Channel",
                creator_avatar_url="https://p16.tiktokcdn.com/a.jpg",
                owner_attested_at=utcnow(),
                status="active",
                live_status="unknown",
            )
        )
        session.add(LocalDailyUsage(user_id=user.id, usage_day=date.today(), used_minutes=5))
        session.add(
            AdminEmailLog(
                user_id=user.id,
                recipient_email="creator@example.com",
                kind="notify.recording_ready",
                subject="Ready",
                status="sent",
                dedupe_key="k1",
                attempts=1,
            )
        )
        session.add(
            PartnerApplication(
                name="Creator Name",
                email="creator@example.com",
                tiktok_handle="my.channel",
                niche="beauty",
                story="My story",
                status="published",
                consent_owns_account=True,
                consent_display=True,
                consent_texts=["ok"],
                terms_version="2026-10-14",
                privacy_version="2026-10-14",
                consent_ip="203.0.113.9",
                published_at=utcnow(),
            )
        )
        await session.commit()
        assert await PrivacyService(session).anonymize_user(user.id)
        await session.commit()
        watch = await session.scalar(select(Watch))
        partner = await session.scalar(select(PartnerApplication))
        log = await session.scalar(select(AdminEmailLog))
        return (
            await session.scalar(select(func.count()).select_from(SocialIdentity)),
            await session.scalar(select(func.count()).select_from(LocalDailyUsage)),
            (watch.creator_display_name, watch.creator_avatar_url, watch.owner_attested_at),
            (partner.email, partner.name, partner.consent_ip, partner.published_at),
            log.recipient_email,
        )

    social, local, watch, partner, recipient = _query(settings, seed_and_erase)
    assert social == 0  # the same Google account can sign up again
    assert local == 0
    assert watch == (None, None, None)
    assert partner[0] == "deleted@deleted.savestream.invalid"
    assert partner[1] == "Deleted user" and partner[2] is None and partner[3] is None
    assert recipient == "deleted@deleted.savestream.invalid"


def test_account_deleted_email(tmp_path) -> None:
    settings, _ = _client(tmp_path, "deleted-email.db")
    sent: list[dict] = []

    def send(**kwargs):
        sent.append(kwargs)

    async def run(session):
        first = await send_account_deleted_email(
            session, settings, {"user_id": "u1", "email": "leaving@example.com"}, send=send
        )
        second = await send_account_deleted_email(
            session, settings, {"user_id": "u1", "email": "leaving@example.com"}, send=send
        )
        anonymized = await send_account_deleted_email(
            session,
            settings,
            {"user_id": "u2", "email": "deleted+ab@deleted.savestream.invalid"},
            send=send,
        )
        return first, second, anonymized

    first, second, anonymized = _query(settings, run)
    assert first == "sent" and second == "duplicate" and anonymized == "skipped"
    assert sent[0]["to"] == "leaving@example.com"
    assert "being deleted" in sent[0]["subject"]


def test_on_device_recording_is_retired(tmp_path) -> None:
    settings, app = _client(tmp_path, "local.db", local_recording_enabled=False)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        access = _signed_up(client, settings, "old.app@example.com")
        headers = {"Authorization": f"Bearer {access}"}
        response = client.post(
            "/v1/local-recordings/sessions",
            json={"watch_id": "00000000-0000-0000-0000-000000000000"},
            headers=headers,
        )
        assert response.status_code == 410
        assert response.json()["error"]["code"] == "LOCAL_RECORDING_RETIRED"
        entitlement = client.get("/v1/me/entitlement", headers=headers).json()
        assert entitlement["local"]["enabled"] is False


def test_mobile_sign_up_consent_switch(tmp_path) -> None:
    settings, app = _client(tmp_path, "consent.db", mobile_consent_required=True)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        missing = client.post(
            "/v1/auth/register",
            json={"email": "new@example.com", "password": PASSWORD, "client_type": "mobile"},
        )
        assert missing.status_code == 428  # same answer the web gets
        assert missing.json()["error"]["code"] == "LEGAL_CONSENT_REQUIRED"
