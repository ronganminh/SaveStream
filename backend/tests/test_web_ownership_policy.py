"""Per-client ownership policy: web attestation, web-only channels hidden from
the Android app, mobile always requires bio verification."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace

import pytest
from sqlalchemy import select

from app.api.schemas.recordings import CreateRecordingRequest, Source
from app.api.schemas.watches import CreateWatchRequest, UpdateWatchRequest
from app.api.serializers.watches import watch_response
from app.application.notifications.push import PushDeliveryService
from app.application.notifications.service import NotificationService
from app.application.recordings.service import RecordingService, utcnow
from app.application.watches.ownership import may_record, mobile_hidden_resources
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import Base, User, UserNotification
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import ChannelOwnershipAttestation, Watch
from tests.credit_helpers import configure_test_pricing, grant_test_credits, mark_test_user_paid
from tests.identity_helpers import identity_settings


def _settings(tmp_path, **changes):
    values = {
        "channel_verification_enforced": True,
        "channel_verification_check_interval_seconds": 0,
        "web_require_ownership": False,
        **changes,
    }
    return replace(identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'own.db'}"), **values)


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
    scopes = scopes_for_role("user")
    web = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes, client_type="web")
    app = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes, client_type="mobile")

    async def close() -> None:
        await session_cm.__aexit__(None, None, None)
        await database.close()

    return session, web, app, close


def _create(name: str, *, attested: bool = False) -> CreateWatchRequest:
    return CreateWatchRequest(
        source=Source(type="username", value=name), auto_record=True, owner_attested=attested
    )


def test_web_attestation_and_app_visibility(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, web, app, close = await _setup(settings)
        try:
            watches = WatchService(session, settings)
            with pytest.raises(ApplicationError) as missing:
                await watches.create(web, _create("web.shop"))
            assert missing.value.code == "OWNERSHIP_ATTESTATION_REQUIRED"

            web_watch = await watches.create(
                web, _create("web.shop", attested=True), ip_address="203.0.113.7", user_agent="UA"
            )
            assert web_watch.added_via == "web"
            assert web_watch.ownership_basis == "web_attested"
            evidence = (await session.scalars(select(ChannelOwnershipAttestation))).all()
            assert len(evidence) == 1
            assert evidence[0].ip_address == "203.0.113.7"
            assert evidence[0].client_type == "web"
            assert evidence[0].statement_version

            # Web may record it without the bio code; the app may not.
            assert may_record(web_watch, settings, client_type="web")
            assert may_record(web_watch, settings, client_type=None)
            assert not may_record(web_watch, settings, client_type="mobile")
            assert watch_response(web_watch, settings=settings).verification_required is False
            hidden_view = watch_response(web_watch, settings=settings, client_type="mobile")
            assert hidden_view.ownership_basis is None

            app_watch = await watches.create(app, _create("app.shop"))
            assert app_watch.added_via == "mobile"
            assert app_watch.ownership_basis is None
            assert not may_record(app_watch, settings, client_type="web")

            # The app never lists, reads or re-adds the web-only channel.
            app_list = await watches.list(app, limit=50, cursor=None, status=None)
            assert [w.id for w in app_list.items] == [app_watch.id]
            web_list = await watches.list(web, limit=50, cursor=None, status=None)
            assert {w.id for w in web_list.items} == {web_watch.id, app_watch.id}
            with pytest.raises(ApplicationError) as not_found:
                await watches.get(app, str(web_watch.id))
            assert not_found.value.status_code == 404
            with pytest.raises(ApplicationError) as conflict:
                await watches.create(app, _create("web.shop"))
            assert conflict.value.code == "CHANNEL_ADDED_ON_WEB"
            assert "watch_id" not in (conflict.value.details or {})

            # Recording from the app is refused; from the web it is allowed.
            recordings = RecordingService(session, settings)
            request = CreateRecordingRequest(source=Source(type="username", value="web.shop"))
            with pytest.raises(ApplicationError):
                await recordings.create(app, request, idempotency_key=str(uuid.uuid4()))
            created = await recordings.create(web, request, idempotency_key=str(uuid.uuid4()))
            assert created.id

            # Strict mode (the production default until the owner flips it).
            strict = replace(settings, web_require_ownership=True)
            assert not may_record(web_watch, strict, client_type="web")
            assert not may_record(web_watch, strict, client_type=None)
        finally:
            await close()

    asyncio.run(run())


def test_app_hides_web_only_recordings_and_notifications(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, web, app, close = await _setup(settings)
        try:
            watches = WatchService(session, settings)
            web_watch = await watches.create(web, _create("@Web.Shop", attested=True))
            await watches.create(app, _create("app.shop"))
            hidden_rec = Recording(
                user_id=web.user_id, source_type="username", source_value="@Web.Shop",
                status="completed",
            )
            shown_rec = Recording(
                user_id=web.user_id, source_type="username", source_value="app.shop",
                status="completed",
            )
            session.add_all([hidden_rec, shown_rec])
            await session.flush()
            notes = [
                UserNotification(
                    user_id=web.user_id, kind="watch_live", title="t", body="b",
                    resource_type="watch", resource_id=str(web_watch.id), dedupe_key="a",
                ),
                UserNotification(
                    user_id=web.user_id, kind="recording_completed", title="t", body="b",
                    resource_type="recording", resource_id=str(hidden_rec.id), dedupe_key="b",
                ),
                UserNotification(
                    user_id=web.user_id, kind="recording_completed", title="t", body="b",
                    resource_type="recording", resource_id=str(shown_rec.id), dedupe_key="c",
                ),
                UserNotification(
                    user_id=web.user_id, kind="system", title="t", body="b", dedupe_key="d",
                ),
            ]
            session.add_all(notes)
            await session.commit()

            recordings = RecordingService(session, settings)
            app_recs = await recordings.list(app, limit=50, cursor=None, status=None)
            assert [r.id for r in app_recs.items] == [shown_rec.id]
            web_recs = await recordings.list(web, limit=50, cursor=None, status=None)
            assert len(web_recs.items) == 2
            with pytest.raises(ApplicationError):
                await recordings.get(app, str(hidden_rec.id))
            assert (await recordings.get(web, str(hidden_rec.id))).id == hidden_rec.id

            service = NotificationService(session)
            app_notes = await service.list(app, limit=50, cursor=None, unread_only=False)
            assert {n.dedupe_key for n in app_notes.items} == {"c", "d"}
            web_notes = await service.list(web, limit=50, cursor=None, unread_only=False)
            assert len(web_notes.items) == 4

            class Sender:
                sent = 0

                async def send(self, push_token, message):
                    Sender.sent += 1

            push = PushDeliveryService(session, Sender())  # type: ignore[arg-type]
            assert await push.deliver(str(notes[0].id)) == 0
            assert await push.deliver(str(notes[1].id)) == 0

            _, rec_ids = await mobile_hidden_resources(session, web.user_id)
            assert rec_ids == {str(hidden_rec.id)}

            # Verifying the channel makes it a normal channel everywhere.
            web_watch.owner_verified_at = utcnow()
            await session.commit()
            app_recs = await recordings.list(app, limit=50, cursor=None, status=None)
            assert len(app_recs.items) == 2
        finally:
            await close()

    asyncio.run(run())


def test_legacy_web_channel_can_be_attested_on_edit(tmp_path) -> None:
    settings = _settings(tmp_path)

    async def run():
        session, web, app, close = await _setup(settings)
        try:
            watches = WatchService(session, settings)
            watch = await watches.create(web, _create("legacy.shop", attested=True))
            watch.ownership_basis = "web_attested_legacy"
            watch.owner_attested_at = None
            await session.commit()
            # Grandfathered: still records on the web.
            assert may_record(watch, settings, client_type="web")

            updated = await watches.update(
                web, str(watch.id), UpdateWatchRequest(owner_attested=True),
                ip_address="198.51.100.2", user_agent="UA",
            )
            assert updated.ownership_basis == "web_attested"
            assert updated.owner_attested_at is not None
            count = len((await session.scalars(select(ChannelOwnershipAttestation))).all())
            assert count == 2
            stored = await session.get(Watch, watch.id)
            assert stored is not None and stored.ownership_basis == "web_attested"
        finally:
            await close()

    asyncio.run(run())
