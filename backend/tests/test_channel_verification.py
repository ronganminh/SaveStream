"""Channel ownership verification: code in the TikTok bio, recording gates,
grace period for existing channels and reminders (Android v2 plan §3.1)."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from datetime import timedelta

import pytest
from sqlalchemy import select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.api.schemas.watches import CreateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.recordings.service import RecordingService, utcnow
from app.application.watches.scheduler import WatchScheduler
from app.application.watches.service import WatchService
from app.application.watches.verification import (
    ChannelProfile,
    ChannelVerificationService,
    bio_contains_code,
    new_code,
)
from app.application.watches.verification_reminders import send_verification_reminders
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, OutboxEvent, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import ChannelVerification, Watch
from app.main import create_app
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings


class FakeProfiles:
    def __init__(self) -> None:
        self.bio: str | None = ""
        self.fail = False
        self.calls: list[str] = []

    async def fetch(self, username: str) -> ChannelProfile | None:
        self.calls.append(username)
        if self.fail:
            raise RuntimeError("TikTok blocked the request")
        return ChannelProfile(username=username, bio=self.bio, tiktok_user_id="7012345")


def _settings(tmp_path, name: str = "verify.db", **changes):
    values = {
        "channel_verification_enforced": True,
        "channel_verification_check_interval_seconds": 0,
        **changes,
    }
    return replace(identity_settings(f"sqlite+aiosqlite:///{tmp_path / name}"), **values)


async def _setup(settings):
    database = Database(settings.database_url)
    async with database.engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    session_cm = database.session()
    session = await session_cm.__aenter__()
    user = User(
        email="owner@example.com",
        normalized_email="owner@example.com",
        role="user",
        email_verified_at=utcnow(),
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    await configure_test_pricing(session, credits_per_unit=1)
    await mark_test_user_paid(session, user.id)
    await grant_test_credits(session, user.id, 500)
    principal = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))
    watch = await WatchService(session, settings).create(
        principal,
        CreateWatchRequest(source=Source(type="username", value="My.Shop_Live"), auto_record=True),
    )

    async def close() -> None:
        await session_cm.__aexit__(None, None, None)
        await database.close()

    return session, principal, watch, close


def test_codes_and_bio_matching() -> None:
    code = new_code()
    assert code.startswith("SS-") and len(code) == 7
    assert not set(code[3:]) & set("01OILU")
    assert bio_contains_code("Live every night 🌙 ss 7k4q", "SS-7K4Q")
    assert bio_contains_code("shop link below | SS-7K4Q", "SS-7K4Q")
    assert not bio_contains_code("SS-7K4P", "SS-7K4Q")
    assert not bio_contains_code("", "SS-7K4Q")


def test_bio_code_verifies_the_channel(tmp_path) -> None:
    settings = _settings(tmp_path)
    profiles = FakeProfiles()

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            new = watch_response(watch, settings=settings)
            assert new.verification_required is True
            assert new.owner_verified_at is None

            service = ChannelVerificationService(session, settings, lookup=profiles)
            started = await service.start(principal, str(watch.id))
            again = await service.start(principal, str(watch.id))
            assert started.code == again.code  # the same code while it is valid
            assert started.checks_left == settings.channel_verification_max_checks

            profiles.bio = "Shop live at 8pm"
            assert (await service.check(principal, str(watch.id))).result == "code_not_found"

            profiles.fail = True  # TikTok WAF / login page: not the user's fault
            assert (await service.check(principal, str(watch.id))).result == "retry_later"
            profiles.fail = False
            profiles.bio = None  # page without a bio
            assert (await service.check(principal, str(watch.id))).result == "retry_later"

            profiles.bio = f"Shop live at 8pm · {started.code.lower()}"
            verified = await service.check(principal, str(watch.id))
            assert verified.result == "verified"
            assert profiles.calls == ["my.shop_live"] * 4

            await session.refresh(watch)
            assert watch.owner_verified_at is not None
            assert watch.verification_method == "bio_code"
            assert watch.owner_verified_tiktok_id == "7012345"
            assert watch_response(watch, settings=settings).verification_required is False
            # Checking again is harmless.
            assert (await service.check(principal, str(watch.id))).result == "verified"
        finally:
            await close()

    asyncio.run(run())


def test_expired_codes_throttling_and_other_users(tmp_path) -> None:
    settings = _settings(
        tmp_path, channel_verification_check_interval_seconds=30, channel_verification_max_checks=2
    )
    profiles = FakeProfiles()

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            service = ChannelVerificationService(session, settings, lookup=profiles)
            first = await service.start(principal, str(watch.id))
            assert (await service.check(principal, str(watch.id))).result == "code_not_found"
            throttled = await service.check(principal, str(watch.id))
            assert throttled.result == "retry_later" and throttled.retry_after_seconds
            assert len(profiles.calls) == 1  # no TikTok request while throttled

            row = await session.scalar(select(ChannelVerification))
            row.last_checked_at = utcnow() - timedelta(minutes=1)
            await session.commit()
            assert (await service.check(principal, str(watch.id))).result == "code_not_found"
            # Out of checks: the code is spent and a new one is issued.
            row.last_checked_at = utcnow() - timedelta(minutes=1)
            await session.commit()
            with pytest.raises(ApplicationError) as spent:
                await service.check(principal, str(watch.id))
            assert spent.value.code == "VERIFICATION_EXPIRED"
            second = await service.start(principal, str(watch.id))
            assert second.code != first.code

            row = await session.scalar(
                select(ChannelVerification).where(ChannelVerification.code == second.code)
            )
            row.expires_at = utcnow() - timedelta(seconds=1)
            await session.commit()
            with pytest.raises(ApplicationError) as expired:
                await service.check(principal, str(watch.id))
            assert expired.value.code == "VERIFICATION_EXPIRED"

            stranger = AuthPrincipal(uuid.uuid4(), uuid.uuid4(), "user", scopes_for_role("user"))
            with pytest.raises(ApplicationError) as hidden:
                await service.start(stranger, str(watch.id))
            assert hidden.value.code == "RESOURCE_NOT_FOUND"
        finally:
            await close()

    asyncio.run(run())


def _manual(username: str) -> CreateRecordingRequest:
    return CreateRecordingRequest(
        source=Source(type="username", value=username), max_duration_seconds=60
    )


def test_only_verified_channels_can_be_recorded(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            recordings = RecordingService(session, settings)
            for source in (
                _manual("my.shop_live"),
                _manual("someone.else"),  # not even a channel of this user
                CreateRecordingRequest(
                    source=Source(type="url", value="https://www.tiktok.com/@someone.else/live"),
                    max_duration_seconds=60,
                ),
            ):
                with pytest.raises(ApplicationError) as blocked:
                    await recordings.create_for_user(
                        principal.user_id, source, idempotency_key=str(uuid.uuid4())
                    )
                assert blocked.value.code == "CHANNEL_NOT_VERIFIED"
                assert blocked.value.status_code == 403

            # Auto-record skips the unverified channel (it is still monitored).
            watch.resolved_room_id = "7695803833239358"
            await session.commit()
            await WatchScheduler(session, settings)._auto_record(watch, "7695803833239358")
            assert await session.scalar(select(Recording.id)) is None

            watch.owner_verified_at = utcnow()
            await session.commit()
            recording = await recordings.create_for_user(
                principal.user_id, _manual("@My.Shop_Live"), idempotency_key=str(uuid.uuid4())
            )
            assert recording.source_value == "my.shop_live"
            await recordings.create_for_user(
                principal.user_id,
                CreateRecordingRequest(
                    source=Source(type="room_id", value="7695803833239358"),
                    max_duration_seconds=60,
                ),
                idempotency_key=str(uuid.uuid4()),
            )
            with pytest.raises(ApplicationError):
                await recordings.create_for_user(
                    principal.user_id, _manual("someone.else"), idempotency_key=str(uuid.uuid4())
                )
        finally:
            await close()

    asyncio.run(run())


def test_existing_channels_keep_recording_during_the_grace_period(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            watch.verification_due_at = utcnow() + timedelta(days=14)
            await session.commit()
            await session.refresh(watch)
            assert watch_response(watch, settings=settings).verification_required is False
            await RecordingService(session, settings).create_for_user(
                principal.user_id, _manual("my.shop_live"), idempotency_key=str(uuid.uuid4())
            )
        finally:
            await close()

    asyncio.run(run())


def test_enforcement_can_be_turned_off(tmp_path) -> None:
    settings = replace(_settings(tmp_path), channel_verification_enforced=False)

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            assert watch_response(watch, settings=settings).verification_required is False
            await RecordingService(session, settings).create_for_user(
                principal.user_id, _manual("someone.else"), idempotency_key=str(uuid.uuid4())
            )
        finally:
            await close()

    asyncio.run(run())


def test_grace_reminders_are_sent_once_per_stage(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            now = utcnow()
            # A channel added today must verify now and gets no grace reminders.
            assert await send_verification_reminders(session, settings, now=now) == 0

            watch.created_at = now - timedelta(days=60)
            watch.verification_due_at = now + timedelta(days=14)
            await session.commit()
            assert await send_verification_reminders(session, settings, now=now) == 1
            assert await send_verification_reminders(session, settings, now=now) == 0
            assert await send_verification_reminders(
                session, settings, now=now + timedelta(days=8)
            ) == 1
            assert await send_verification_reminders(
                session, settings, now=now + timedelta(days=15)
            ) == 1
            assert await send_verification_reminders(
                session, settings, now=now + timedelta(days=16)
            ) == 0

            titles = [
                row.title
                for row in (
                    await session.scalars(
                        select(UserNotification).order_by(UserNotification.created_at)
                    )
                ).all()
            ]
            assert titles == [
                "Verify your channel to keep recording",
                "7 days left to verify your channel",
                "Recording is paused until you verify",
            ]
            emails = (
                await session.scalars(
                    select(OutboxEvent).where(OutboxEvent.topic == "account.email")
                )
            ).all()
            assert len(emails) == 3
            assert {event.payload["kind"] for event in emails} == {"channel_verification_needed"}
        finally:
            await close()

    asyncio.run(run())


def test_routes_are_registered(tmp_path) -> None:
    app = create_app(_settings(tmp_path, "routes.db"))
    paths = app.openapi()["paths"]
    assert set(paths["/v1/watches/{watch_id}/verification"]) == {"get", "post"}
    assert "post" in paths["/v1/watches/{watch_id}/verification/check"]
    # Admin routes are hidden from the public OpenAPI document.
    admin = {(route.path, method) for route in app.routes for method in getattr(route, "methods", ())}
    assert ("/v1/admin/watches/{watch_id}/verify", "POST") in admin
