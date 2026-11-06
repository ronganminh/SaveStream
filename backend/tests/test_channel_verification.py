"""Channel ownership verification: code in the TikTok bio, recording gates,
grace period for existing channels and reminders (Android v2 plan §3.1)."""

from __future__ import annotations

import asyncio
import logging
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
from app.settings import AppSettings
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


async def _past_still_checking(session) -> None:
    """Move the first check more than 5 minutes into the past."""
    for row in (await session.scalars(select(ChannelVerification))).all():
        if row.first_checked_at is not None:
            row.first_checked_at = utcnow() - timedelta(minutes=6)
    await session.commit()


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
    # Full-width characters (some keyboards) and invisible characters pasted
    # along with the code still match.
    assert bio_contains_code("Ｌｉｖｅ　ＳＳ－７Ｋ４Ｑ", "SS-7K4Q")
    assert bio_contains_code("ss\u200b-7k\u200d4\u2060q\ufeff", "SS-7K4Q")
    assert bio_contains_code("SS\u200e7K\u200f4Q", "SS-7K4Q")
    assert not bio_contains_code("anything", "")


def test_defaults_give_a_day_of_checks(monkeypatch) -> None:
    monkeypatch.setenv("SAVESTREAM_ENVIRONMENT", "local")
    for name in ("CODE_TTL_SECONDS", "MAX_CHECKS", "CHECK_INTERVAL_SECONDS"):
        monkeypatch.delenv(f"SAVESTREAM_CHANNEL_VERIFICATION_{name}", raising=False)
    settings = AppSettings.from_env()
    assert settings.channel_verification_code_ttl_seconds == 86400
    assert settings.channel_verification_max_checks == 200
    assert settings.channel_verification_check_interval_seconds == 10


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
            # Right after the first check TikTok may still show the old bio.
            first = await service.check(principal, str(watch.id))
            assert first.result == "retry_later"
            assert first.reason == "still_checking"
            assert first.retry_after_seconds == 15
            assert first.message and "TikTok can take a minute" in first.message
            await _past_still_checking(session)
            missing = await service.check(principal, str(watch.id))
            assert missing.result == "code_not_found"
            assert missing.message and "wait a minute" in missing.message

            profiles.fail = True  # TikTok WAF / login page: not the user's fault
            unavailable = await service.check(principal, str(watch.id))
            assert unavailable.result == "retry_later"
            assert unavailable.reason == "tiktok_unavailable"
            profiles.fail = False
            profiles.bio = None  # page without a bio
            assert (await service.check(principal, str(watch.id))).result == "retry_later"

            profiles.bio = f"Shop live at 8pm · {started.code.lower()}"
            verified = await service.check(principal, str(watch.id))
            assert verified.result == "verified"
            assert profiles.calls == ["my.shop_live"] * 5

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
            assert (await service.check(principal, str(watch.id))).reason == "still_checking"
            throttled = await service.check(principal, str(watch.id))
            assert throttled.result == "retry_later" and throttled.retry_after_seconds
            assert throttled.reason == "too_soon"
            assert len(profiles.calls) == 1  # no TikTok request while throttled
            await _past_still_checking(session)

            row = await session.scalar(select(ChannelVerification))
            row.last_checked_at = utcnow() - timedelta(minutes=1)
            await session.commit()
            assert (await service.check(principal, str(watch.id))).result == "code_not_found"
            # Out of checks: the code is spent and reissued with the same value,
            # so the code already in the bio keeps working.
            row.last_checked_at = utcnow() - timedelta(minutes=1)
            await session.commit()
            with pytest.raises(ApplicationError) as spent:
                await service.check(principal, str(watch.id))
            assert spent.value.code == "VERIFICATION_EXPIRED"
            second = await service.start(principal, str(watch.id))
            assert second.code == first.code
            assert second.checks_left == settings.channel_verification_max_checks

            row = await session.scalar(
                select(ChannelVerification).where(ChannelVerification.status == "pending")
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


def test_codes_from_the_last_7_days_still_verify(tmp_path) -> None:
    settings = _settings(tmp_path)
    profiles = FakeProfiles()

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            service = ChannelVerificationService(session, settings, lookup=profiles)
            current = await service.start(principal, str(watch.id))
            # Codes an older app version issued for this channel.
            now = utcnow()
            for code, age in (("SS-AAAA", timedelta(days=8)), ("SS-BBBB", timedelta(days=6))):
                session.add(
                    ChannelVerification(
                        user_id=principal.user_id,
                        watch_id=watch.id,
                        username="my.shop_live",
                        code=code,
                        status="expired",
                        attempts=20,
                        expires_at=now - age + timedelta(minutes=30),
                        created_at=now - age,
                    )
                )
            await session.commit()

            profiles.bio = "old code SS-AAAA"
            await service.check(principal, str(watch.id))
            await _past_still_checking(session)
            assert (await service.check(principal, str(watch.id))).result == "code_not_found"

            profiles.bio = "ＳＳ－ＢＢＢＢ"
            verified = await service.check(principal, str(watch.id))
            assert verified.result == "verified"
            assert current.code not in {"SS-AAAA", "SS-BBBB"}
        finally:
            await close()

    asyncio.run(run())


def test_new_codes_are_still_limited_per_hour(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            service = ChannelVerificationService(session, settings, lookup=FakeProfiles())
            codes = set()
            for _ in range(10):
                codes.add((await service.start(principal, str(watch.id))).code)
                for row in (await session.scalars(select(ChannelVerification))).all():
                    row.expires_at = utcnow() - timedelta(seconds=1)
                await session.commit()
            assert len(codes) == 1  # always the same code for the channel
            with pytest.raises(ApplicationError) as limited:
                await service.start(principal, str(watch.id))
            assert limited.value.code == "RATE_LIMITED"
        finally:
            await close()

    asyncio.run(run())


def test_outcomes_are_logged_without_personal_data(tmp_path, caplog) -> None:
    settings = _settings(tmp_path)
    profiles = FakeProfiles()

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            service = ChannelVerificationService(session, settings, lookup=profiles)
            started = await service.start(principal, str(watch.id))
            profiles.bio = "Secret bio text"
            await service.check(principal, str(watch.id))
            await _past_still_checking(session)
            await service.check(principal, str(watch.id))
            profiles.fail = True
            await service.check(principal, str(watch.id))
            profiles.fail = False
            profiles.bio = f"Secret bio text {started.code}"
            await service.check(principal, str(watch.id))
            return started.code
        finally:
            await close()

    with caplog.at_level(logging.INFO, logger="app.application.watches.verification"):
        code = asyncio.run(run())

    lines = [
        record.getMessage()
        for record in caplog.records
        if record.getMessage().startswith("channel_verification ")
    ]
    assert [line.split()[1] for line in lines] == [
        "outcome=started",
        "outcome=still_checking",
        "outcome=code_not_found",
        "outcome=unavailable",
        "outcome=verified",
    ]
    assert lines[-1].endswith("attempts=4")
    text = "\n".join(lines)
    for secret in (code, "Secret", "my.shop_live", "My.Shop_Live"):
        assert secret not in text


def test_expired_check_is_logged(tmp_path, caplog) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, principal, watch, close = await _setup(settings)
        try:
            service = ChannelVerificationService(session, settings, lookup=FakeProfiles())
            with pytest.raises(ApplicationError):
                await service.check(principal, str(watch.id))
        finally:
            await close()

    with caplog.at_level(logging.INFO, logger="app.application.watches.verification"):
        asyncio.run(run())
    assert any("outcome=expired" in record.getMessage() for record in caplog.records)


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
