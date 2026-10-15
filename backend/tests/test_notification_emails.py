"""Notification emails: per-kind switches, anti-spam limits, one-click
unsubscribe, and Partner Program replies."""

from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.application.notifications.service import (
    ensure_creator_live_notification,
    ensure_credits_low_notification,
    ensure_recording_notification,
)
from app.application.notifications.unsubscribe import make_token
from app.infrastructure.db.admin_models import AdminEmailLog, PartnerApplication
from app.infrastructure.db.models import NotificationPreference, OutboxEvent, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.notifications.email_delivery import (
    HOURLY_CAP,
    send_notification_email,
    send_partner_email,
)
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings


class Outbox:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    def __call__(self, *, to, subject, text, html, headers=None) -> None:
        self.sent.append({"to": to, "subject": subject, "text": text, "headers": headers or {}})


def _setup(tmp_path):
    url = f"sqlite+aiosqlite:///{tmp_path / 'emails.db'}"
    create_schema(url)
    return identity_settings(url), url


async def _user(session, email="maya@example.com", **prefs) -> User:
    user = User(
        email=email,
        normalized_email=email,
        role="user",
        email_verified_at=datetime.now(timezone.utc),
    )
    session.add(user)
    await session.flush()
    if prefs:
        session.add(NotificationPreference(user_id=user.id, **prefs))
    await session.commit()
    return user


async def _watch(session, user: User, name="maya.live") -> Watch:
    watch = Watch(
        user_id=user.id,
        source_type="username",
        source_value=name,
        resolved_username=name,
        status="active",
        live_status="live",
        auto_record=True,
        notify_on_live=True,
    )
    session.add(watch)
    await session.commit()
    return watch


async def _email_events(session) -> list[dict]:
    rows = (
        await session.scalars(select(OutboxEvent).where(OutboxEvent.topic == "notification.email"))
    ).all()
    return [row.payload for row in rows]


def test_live_email_has_unsubscribe_headers_and_a_six_hour_cooldown(tmp_path) -> None:
    settings, url = _setup(tmp_path)
    outbox = Outbox()

    async def run():
        database = Database(url)
        try:
            async with database.session() as session:
                user = await _user(session)
                watch = await _watch(session, user)
                await ensure_creator_live_notification(session, watch, live_session_id=uuid.uuid4())
                await ensure_creator_live_notification(session, watch, live_session_id=uuid.uuid4())
                await session.commit()
                first, second = await _email_events(session)
                now = datetime.now(timezone.utc)
                results = [
                    await send_notification_email(session, settings, first, send=outbox, now=now),
                    await send_notification_email(session, settings, first, send=outbox, now=now),
                    await send_notification_email(
                        session, settings, second, send=outbox, now=now + timedelta(minutes=30)
                    ),
                ]
                return results, user
        finally:
            await database.close()

    results, user = asyncio.run(run())
    assert results == ["sent", "duplicate", "cooldown"]
    [mail] = outbox.sent
    assert mail["to"] == "maya@example.com"
    assert mail["subject"] == "@maya.live is LIVE now"
    assert "/unsubscribe?token=" in mail["text"]
    assert mail["headers"]["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click"
    assert "/v1/public/email/unsubscribe?token=" in mail["headers"]["List-Unsubscribe"]


def test_email_switch_off_and_app_switch_off_are_independent(tmp_path) -> None:
    settings, url = _setup(tmp_path)

    async def run():
        database = Database(url)
        try:
            async with database.session() as session:
                # App notification off, email on: no inbox item, email queued.
                a = await _user(session, "a@example.com", creator_live=False)
                await ensure_creator_live_notification(
                    session, await _watch(session, a, "a.live"), live_session_id=uuid.uuid4()
                )
                # Email off, app on: inbox item, no email.
                b = await _user(session, "b@example.com", email_creator_live=False)
                await ensure_creator_live_notification(
                    session, await _watch(session, b, "b.live"), live_session_id=uuid.uuid4()
                )
                await session.commit()
                events = await _email_events(session)
                inbox = (await session.scalars(select(UserNotification))).all()
                return events, inbox, a, b
        finally:
            await database.close()

    events, inbox, a, b = asyncio.run(run())
    assert [event["user_id"] for event in events] == [str(a.id)]
    assert [item.user_id for item in inbox] == [b.id]


def test_per_user_hourly_cap_suppresses_extra_emails(tmp_path) -> None:
    settings, url = _setup(tmp_path)
    outbox = Outbox()

    async def run():
        database = Database(url)
        try:
            async with database.session() as session:
                user = await _user(session)
                results = []
                for index in range(HOURLY_CAP + 1):
                    recording = Recording(
                        user_id=user.id,
                        source_type="username",
                        source_value=f"creator{index}",
                        resolved_username=f"creator{index}",
                        status="completed",
                        quality="best",
                        container="mp4",
                    )
                    session.add(recording)
                    await session.flush()
                    await ensure_recording_notification(session, recording, "recording.completed")
                await session.commit()
                for event in await _email_events(session):
                    results.append(await send_notification_email(session, settings, event, send=outbox))
                logs = (await session.scalars(select(AdminEmailLog))).all()
                return results, logs
        finally:
            await database.close()

    results, logs = asyncio.run(run())
    assert results == ["sent"] * HOURLY_CAP + ["rate_limited"]
    assert len(outbox.sent) == HOURLY_CAP
    assert sorted({log.status for log in logs}) == ["sent", "suppressed"]


def test_unsubscribe_link_turns_off_only_that_email(tmp_path) -> None:
    settings, url = _setup(tmp_path)
    app = create_app(settings)

    async def seed() -> uuid.UUID:
        database = Database(url)
        try:
            async with database.session() as session:
                return (await _user(session)).id
        finally:
            await database.close()

    user_id = asyncio.run(seed())
    token = make_token(settings.jwt_secret, user_id, "email_recording_ready")
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        tampered = client.post(
            "/v1/public/email/unsubscribe",
            json={"token": token.replace("email_recording_ready", "email_credits_low")},
        )
        assert tampered.status_code == 400
        page = client.post("/v1/public/email/unsubscribe", json={"token": token})
        assert page.status_code == 200, page.text
        assert page.json() == {"preference": "email_recording_ready", "label": "Recording ready"}
        # RFC 8058 one-click POST from a mail app, token in the URL.
        one_click = client.post(
            f"/v1/public/email/unsubscribe?token={make_token(settings.jwt_secret, user_id, 'email_creator_live')}",
            content="List-Unsubscribe=One-Click",
            headers={"content-type": "application/x-www-form-urlencoded"},
        )
        assert one_click.status_code == 200

    async def read() -> NotificationPreference | None:
        database = Database(url)
        try:
            async with database.session() as session:
                return await session.get(NotificationPreference, user_id)
        finally:
            await database.close()

    prefs = asyncio.run(read())
    assert prefs is not None
    assert prefs.email_recording_ready is False and prefs.email_creator_live is False
    assert prefs.email_recording_failed is True and prefs.recording_ready is True


def test_credits_low_once_a_day_and_partner_replies(tmp_path) -> None:
    settings, url = _setup(tmp_path)
    outbox = Outbox()

    async def run():
        database = Database(url)
        try:
            async with database.session() as session:
                user = await _user(session)
                day = datetime.now(timezone.utc).date()
                none_high = await ensure_credits_low_notification(
                    session, user_id=user.id, available=500, usage_day=day
                )
                low = await ensure_credits_low_notification(
                    session, user_id=user.id, available=30, usage_day=day
                )
                again = await ensure_credits_low_notification(
                    session, user_id=user.id, available=20, usage_day=day
                )
                application = PartnerApplication(
                    id=uuid.uuid4(),
                    name="Maya Chen",
                    email="maya@example.com",
                    tiktok_handle="mayafit",
                    niche="Fitness",
                    story="x" * 30,
                    status="pending",
                    consent_owns_account=True,
                    consent_display=True,
                    consent_texts=["a", "b"],
                    terms_version="t",
                    privacy_version="p",
                )
                session.add(application)
                await session.commit()
                partner = [
                    await send_partner_email(session, settings, str(application.id), "partner_received", send=outbox),
                    await send_partner_email(session, settings, str(application.id), "partner_received", send=outbox),
                    await send_partner_email(session, settings, str(application.id), "partner_approved", send=outbox),
                ]
                events = await _email_events(session)
                return none_high, low, again, partner, events
        finally:
            await database.close()

    none_high, low, again, partner, events = asyncio.run(run())
    assert none_high is None and low is not None and again is not None and again.id == low.id
    assert [event["kind"] for event in events] == ["credits_low"]
    assert partner == ["sent", "duplicate", "sent"]
    assert outbox.sent[1]["subject"] == "Your SaveStream partner application was approved"
    assert outbox.sent[0]["subject"].startswith("We received your SaveStream partner application (PA-")
    assert "50 free recording hours" in outbox.sent[0]["text"]
