"""Channel API gaps found by the Android v2 Channels screens: a distinct
CHANNEL_NOT_FOUND for live-status, the pending bio code and per-channel
recording numbers on Watch responses."""

from __future__ import annotations

import asyncio
import json
import uuid
from datetime import timedelta

from fastapi.testclient import TestClient
from sqlalchemy import event, func, select

from app.api.dependencies import get_current_principal
from app.application.recordings.service import utcnow
from app.application.watches.channel_stats import watch_extras
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.creators.tiktok_profile import CreatorLookupResult
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import ChannelVerification, Watch
from app.infrastructure.recording.runtime import RecordingRuntime, ResolvedSource
from app.main import create_app
from core.tiktok_api import TikTokAPI
from tests.identity_helpers import identity_settings

# --- TikTok "user not found" signal -------------------------------------------------


class _Response:
    def __init__(self, text: str, status_code: int = 200) -> None:
        self.text = text
        self.status_code = status_code

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise RuntimeError(f"HTTP {self.status_code}")


class _Client:
    def __init__(self, pages: dict[str, _Response]) -> None:
        self.pages = pages
        self.cookies: dict[str, str] = {}

    def get(self, url=None, **_kwargs):
        return self.pages.get(url, _Response("", 404))


def _api(pages: dict[str, _Response]) -> TikTokAPI:
    api = TikTokAPI.__new__(TikTokAPI)
    api.BASE_URL = "https://www.tiktok.com"
    api.WEBCAST_URL = "https://webcast.tiktok.com"
    api.http_client = _Client(pages)
    api._http_client_stream = api.http_client
    return api


def _universal(detail: dict) -> str:
    payload = {"__DEFAULT_SCOPE__": {"webapp.app-context": {}, "webapp.user-detail": detail}}
    return (
        '<script id="__UNIVERSAL_DATA_FOR_REHYDRATION__" type="application/json">'
        + json.dumps(payload)
        + "</script>"
    )


# What https://www.tiktok.com/@<unknown handle> serves (trimmed); the LIVE page
# of an unknown handle has only an empty CurrentRoom, like a creator who never
# went LIVE.
UNKNOWN_PROFILE = _universal({"statusCode": 10221, "statusMsg": "user banned", "needFix": False})
UNKNOWN_LIVE_PAGE = (
    '<script id="SIGI_STATE" type="application/json">'
    '{"CurrentRoom":{"roomInfo":null,"anchorId":"","roomId":""}}</script>'
)


def test_profile_page_status_code_marks_unknown_handle_not_found() -> None:
    api = _api(
        {
            "https://www.tiktok.com/@ghost": _Response(UNKNOWN_PROFILE),
            "https://www.tiktok.com/@ghost/live/": _Response(UNKNOWN_LIVE_PAGE),
        }
    )
    result = api.lookup_user_profile("@ghost")
    assert result.profile is None
    assert result.not_found is True
    assert api.get_user_profile("ghost") is None

    older = _api({"https://www.tiktok.com/@ghost": _Response(_universal({"statusCode": 10202}))})
    assert older.lookup_user_profile("ghost").not_found is True


def test_unclear_profile_pages_are_never_reported_as_not_found() -> None:
    real = _universal(
        {
            "statusCode": 0,
            "userInfo": {"user": {"uniqueId": "creator", "nickname": "Creator", "id": "42"}},
        }
    )
    cases = {
        "found": {"https://www.tiktok.com/@creator": _Response(real)},
        "waf shell": {"https://www.tiktok.com/@creator": _Response("<html>Please wait...</html>")},
        "http error": {"https://www.tiktok.com/@creator": _Response(UNKNOWN_PROFILE, 503)},
        "other status": {
            "https://www.tiktok.com/@creator": _Response(_universal({"statusCode": 10101}))
        },
        # Only the profile page can say "no such account".
        "live page only": {
            "https://www.tiktok.com/@creator/live/": _Response(UNKNOWN_PROFILE),
        },
    }
    for name, pages in cases.items():
        result = _api(pages).lookup_user_profile("creator")
        assert result.not_found is False, name
    assert _api(cases["found"]).lookup_user_profile("creator").profile is not None


# --- POST /v1/live-status ---------------------------------------------------------


class _Resolver:
    def __init__(self, *, fail: bool) -> None:
        self.fail = fail

    def resolve(self, source):
        raise NotImplementedError

    def live_status(self, source):
        if self.fail:
            # What TikTokAPI raises for an unknown handle, an offline creator
            # who never went LIVE and a TikTok outage alike.
            raise RuntimeError("The user is not hosting a live stream at the moment.")
        return ResolvedSource(username=source.value, room_id="7312345"), True


def _live_status_client(tmp_path, monkeypatch, *, fail: bool, lookup: CreatorLookupResult):
    from app.api.routes import recordings as recordings_routes
    from app.infrastructure.creators import tiktok_profile

    async def resolve(self, source):
        return lookup

    monkeypatch.setattr(
        recordings_routes,
        "build_recording_runtime",
        lambda settings: RecordingRuntime(resolver=_Resolver(fail=fail), gateway=None),  # type: ignore[arg-type]
    )
    monkeypatch.setattr(tiktok_profile.TikTokCreatorMetadataLookup, "resolve", resolve)
    app = create_app(identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'live.db'}"))
    app.dependency_overrides[get_current_principal] = lambda: AuthPrincipal(
        uuid.uuid4(), uuid.uuid4(), "user", scopes_for_role("user")
    )
    return TestClient(app, base_url="https://testserver")


def test_live_status_answers_unknown_handle_with_channel_not_found(tmp_path, monkeypatch) -> None:
    with _live_status_client(
        tmp_path, monkeypatch, fail=True, lookup=CreatorLookupResult(metadata=None, not_found=True)
    ) as client:
        response = client.post(
            "/v1/live-status", json={"source": {"type": "username", "value": "ghost"}}
        )
    assert response.status_code == 404, response.text
    error = response.json()["error"]
    assert error["code"] == "CHANNEL_NOT_FOUND"
    assert error["retryable"] is False


def test_live_status_keeps_503_when_tiktok_cannot_say(tmp_path, monkeypatch) -> None:
    with _live_status_client(
        tmp_path, monkeypatch, fail=True, lookup=CreatorLookupResult(metadata=None)
    ) as client:
        response = client.post(
            "/v1/live-status", json={"source": {"type": "username", "value": "creator"}}
        )
    assert response.status_code == 503, response.text
    assert response.json()["error"]["code"] == "STREAM_UNAVAILABLE"
    assert response.json()["error"]["retryable"] is True


def test_live_status_success_ignores_profile_page(tmp_path, monkeypatch) -> None:
    with _live_status_client(
        tmp_path, monkeypatch, fail=False, lookup=CreatorLookupResult(metadata=None, not_found=True)
    ) as client:
        response = client.post(
            "/v1/live-status", json={"source": {"type": "username", "value": "creator"}}
        )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["live_status"] == "live"
    assert body["creator"]["username"] == "creator"


# --- Watch responses --------------------------------------------------------------


def _watch(user_id: uuid.UUID, username: str, **values) -> Watch:
    return Watch(
        user_id=user_id,
        source_type="username",
        source_value=username,
        active_dedupe_key=uuid.uuid4().hex,
        resolved_username=values.pop("resolved_username", username),
        status="active",
        live_status="offline",
        auto_record=False,
        next_check_at=utcnow(),
        **values,
    )


def _recording(user_id: uuid.UUID, username: str | None, **values) -> Recording:
    return Recording(
        user_id=user_id,
        source_type=values.pop("source_type", "username"),
        source_value=values.pop("source_value", username or "room"),
        resolved_username=username,
        status=values.pop("status", "completed"),
        quality="best",
        container="mp4",
        **values,
    )


async def _seed(database_url: str):
    database = Database(database_url)
    try:
        async with database.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with database.session() as session:
            user = User(
                email="channels@example.com",
                normalized_email="channels@example.com",
                role="user",
                email_verified_at=utcnow(),
            )
            other = User(
                email="other@example.com",
                normalized_email="other@example.com",
                role="user",
                email_verified_at=utcnow(),
            )
            session.add_all([user, other])
            await session.commit()
            now = utcnow()
            pending = _watch(user.id, "pending.creator", resolved_room_id="room-p")
            expired = _watch(user.id, "expired.creator")
            verified = _watch(user.id, "verified.creator", owner_verified_at=now)
            empty = _watch(user.id, "empty.creator")
            session.add_all([pending, expired, verified, empty])
            await session.commit()
            session.add_all(
                [
                    # An older code that was replaced, then the active one.
                    ChannelVerification(
                        user_id=user.id,
                        watch_id=pending.id,
                        username="pending.creator",
                        code="SS-OLD1",
                        status="expired",
                        attempts=0,
                        expires_at=now + timedelta(minutes=5),
                        created_at=now - timedelta(minutes=20),
                    ),
                    ChannelVerification(
                        user_id=user.id,
                        watch_id=pending.id,
                        username="pending.creator",
                        code="SS-7K4Q",
                        status="pending",
                        attempts=1,
                        expires_at=now + timedelta(minutes=25),
                        created_at=now - timedelta(minutes=5),
                    ),
                    ChannelVerification(
                        user_id=user.id,
                        watch_id=expired.id,
                        username="expired.creator",
                        code="SS-GONE",
                        status="pending",
                        attempts=0,
                        expires_at=now - timedelta(minutes=1),
                        created_at=now - timedelta(minutes=31),
                    ),
                    ChannelVerification(
                        user_id=user.id,
                        watch_id=verified.id,
                        username="verified.creator",
                        code="SS-DONE",
                        status="pending",
                        attempts=0,
                        expires_at=now + timedelta(minutes=10),
                        created_at=now - timedelta(minutes=1),
                    ),
                    # pending.creator: 3 visible recordings, 1 deleted.
                    _recording(
                        user.id,
                        "Pending.Creator",
                        duration_seconds=600,
                        started_at=now - timedelta(days=2, minutes=12),
                        ended_at=now - timedelta(days=2),
                    ),
                    _recording(
                        user.id,
                        "pending.creator",
                        status="stopped",
                        duration_seconds=1500,
                        started_at=now - timedelta(days=1, minutes=30),
                        ended_at=now - timedelta(days=1),
                    ),
                    # Matched by room id; failed, so it counts but is not "last LIVE".
                    _recording(
                        user.id,
                        None,
                        source_type="room_id",
                        source_value="room-p",
                        room_id="room-p",
                        status="failed",
                        duration_seconds=40,
                        ended_at=now - timedelta(hours=1),
                    ),
                    _recording(
                        user.id,
                        "pending.creator",
                        duration_seconds=9999,
                        ended_at=now - timedelta(minutes=10),
                        deleted_at=now - timedelta(minutes=5),
                    ),
                    # verified.creator: one recording.
                    _recording(
                        user.id,
                        "verified.creator",
                        duration_seconds=120,
                        ended_at=now - timedelta(hours=3),
                    ),
                    # Another user's recording of the same creator.
                    _recording(
                        other.id,
                        "pending.creator",
                        duration_seconds=7000,
                        ended_at=now - timedelta(minutes=2),
                    ),
                ]
            )
            await session.commit()
            principal = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))
            return principal, {
                "pending": pending.id,
                "expired": expired.id,
                "verified": verified.id,
                "empty": empty.id,
            }
    finally:
        await database.close()


async def _verification_rows(database_url: str) -> list[tuple[str, str]]:
    database = Database(database_url)
    try:
        async with database.session() as session:
            rows = (
                await session.execute(
                    select(ChannelVerification.code, ChannelVerification.status).order_by(
                        ChannelVerification.code
                    )
                )
            ).all()
            return [(code, status) for code, status in rows]
    finally:
        await database.close()


def test_watch_responses_carry_pending_code_and_recording_stats(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'stats.db'}"
    principal, ids = asyncio.run(_seed(database_url))
    before = asyncio.run(_verification_rows(database_url))

    app = create_app(identity_settings(database_url))
    app.dependency_overrides[get_current_principal] = lambda: principal
    with TestClient(app, base_url="https://testserver") as client:
        listed = client.get("/v1/watches", params={"limit": 100})
        assert listed.status_code == 200, listed.text
        items = {item["id"]: item for item in listed.json()["items"]}
        single = client.get(f"/v1/watches/{ids['pending']}")
        assert single.status_code == 200, single.text

    pending = items[str(ids["pending"])]
    assert pending["pending_verification_code"] == "SS-7K4Q"
    assert pending["pending_verification_expires_at"] is not None
    assert pending["recording_count"] == 3
    assert pending["total_recorded_seconds"] == 600 + 1500 + 40
    # The stopped recording ended last among the finished ones.
    assert pending["last_live_duration_seconds"] == 1500
    assert single.json() == pending

    expired = items[str(ids["expired"])]
    assert expired["pending_verification_code"] is None
    assert expired["pending_verification_expires_at"] is None

    verified = items[str(ids["verified"])]
    assert verified["pending_verification_code"] is None
    assert verified["recording_count"] == 1
    assert verified["total_recorded_seconds"] == 120
    assert verified["last_live_duration_seconds"] == 120

    empty = items[str(ids["empty"])]
    assert empty["recording_count"] == 0
    assert empty["total_recorded_seconds"] == 0
    assert empty["last_live_duration_seconds"] is None
    assert empty["pending_verification_code"] is None

    # Reading never creates a code or marks an expired one.
    assert asyncio.run(_verification_rows(database_url)) == before


def test_watch_extras_use_a_fixed_number_of_queries(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'queries.db'}"
    principal, _ids = asyncio.run(_seed(database_url))
    settings = identity_settings(database_url)

    async def count_queries(watch_limit: int) -> int:
        database = Database(database_url)
        statements: list[str] = []

        def record(_conn, _cursor, statement, *_args) -> None:
            statements.append(statement)

        try:
            async with database.session() as session:
                watches = list(
                    (
                        await session.scalars(
                            select(Watch)
                            .where(Watch.user_id == principal.user_id)
                            # Unverified first, so one Watch still reads codes.
                            .order_by(Watch.owner_verified_at.is_not(None), Watch.id)
                            .limit(watch_limit)
                        )
                    ).all()
                )
                assert len(watches) == watch_limit
                event.listen(database.engine.sync_engine, "before_cursor_execute", record)
                await watch_extras(
                    session, settings, user_id=principal.user_id, watches=watches
                )
                event.remove(database.engine.sync_engine, "before_cursor_execute", record)
                count = await session.scalar(select(func.count()).select_from(Watch))
                assert count == 4
        finally:
            await database.close()
        return len(statements)

    assert asyncio.run(count_queries(1)) == asyncio.run(count_queries(4)) == 3
