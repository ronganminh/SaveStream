"""TikTok CDN avatar URLs expire; SaveStream keeps a copy in object storage
behind a stable public URL that web and mobile both receive as
`creator.avatar_url`, and refreshes it periodically."""

from __future__ import annotations

import asyncio
import uuid
from dataclasses import replace
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.api.schemas.recordings import Source
from app.api.serializers.watches import watch_response
from app.application.creators.avatar_cache import (
    CreatorAvatarCache,
    avatar_key,
    recording_avatar_urls,
)
from app.application.watches.service import CreatorMetadata
from app.infrastructure.creators.avatar_fetch import avatar_url_allowed
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.rate_limit import InMemoryRateLimiter
from app.main import create_app
from tests.identity_helpers import identity_settings

OLD_CDN = "https://p16-sign-va.tiktokcdn.com/avatar-old.jpeg?x-expires=1"
NEW_CDN = "https://p16-sign-va.tiktokcdn.com/avatar-new.jpeg?x-expires=2"
NOW = datetime(2026, 10, 14, 12, 0, tzinfo=timezone.utc)


class _Storage:
    def __init__(self) -> None:
        self.objects: dict[str, tuple[bytes, str]] = {}

    def upload_bytes(self, data, storage_key, *, content_type, cache_control=None) -> None:
        self.objects[storage_key] = (data, content_type)

    def get_bytes(self, storage_key, *, max_bytes):
        return self.objects.get(storage_key)

    def remove(self, storage_key) -> None:
        self.objects.pop(storage_key, None)

    async def ping(self) -> bool:
        return True


class _Lookup:
    def __init__(self) -> None:
        self.calls = 0

    async def lookup(self, source: Source) -> CreatorMetadata | None:
        self.calls += 1
        return CreatorMetadata(username="p.c.dat25", display_name="VL", avatar_url=NEW_CDN)


def _settings(tmp_path):
    return replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'avatars.db'}"),
        public_api_base_url="https://api.savestream.test",
    )


async def _seed(settings) -> tuple[uuid.UUID, uuid.UUID]:
    database = Database(settings.database_url)
    try:
        async with database.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        async with database.session() as session:
            user = User(email="a@example.com", normalized_email="a@example.com", role="user")
            session.add(user)
            await session.flush()
            watch = Watch(
                user_id=user.id,
                source_type="username",
                source_value="p.c.dat25",
                resolved_username="p.c.dat25",
                creator_display_name="VL",
                creator_avatar_url=OLD_CDN,
            )
            session.add(watch)
            await session.commit()
            return user.id, watch.id
    finally:
        await database.close()


def test_avatar_is_copied_served_and_refreshed_when_the_cdn_url_expires(tmp_path) -> None:
    settings = _settings(tmp_path)
    _, watch_id = asyncio.run(_seed(settings))
    storage = _Storage()
    lookup = _Lookup()
    live = {OLD_CDN: (b"old-jpeg", "image/jpeg"), NEW_CDN: (b"new-jpeg", "image/jpeg")}

    async def refresh(now: datetime) -> Watch:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                await CreatorAvatarCache(
                    session, settings, storage, live.get, lookup
                ).refresh_due(now=now)
                watch = await session.get(Watch, watch_id)
                assert watch is not None
                return watch
        finally:
            await database.close()

    # First copy: the raw URL still works, no profile lookup needed.
    watch = asyncio.run(refresh(NOW))
    assert watch.creator_avatar_key is not None
    avatar_id = watch.creator_avatar_key.removeprefix("creator-avatars/")
    assert watch.creator_avatar_cached_url == (
        f"https://api.savestream.test/v1/public/creator-avatars/{avatar_id}"
    )
    assert storage.objects[watch.creator_avatar_key] == (b"old-jpeg", "image/jpeg")
    assert lookup.calls == 0
    # Web and mobile get the stable URL, not the expiring CDN one.
    assert watch_response(watch).creator.avatar_url == watch.creator_avatar_cached_url

    # Within the refresh period nothing is fetched again.
    del live[OLD_CDN]
    asyncio.run(refresh(NOW + timedelta(hours=1)))
    assert lookup.calls == 0

    # After the period the old CDN URL is dead: look the profile up again and
    # overwrite the same object, so the public URL never changes.
    watch = asyncio.run(refresh(NOW + timedelta(hours=settings.creator_avatar_refresh_hours + 1)))
    assert lookup.calls == 1
    assert watch.creator_avatar_url == NEW_CDN
    assert watch.creator_avatar_key == avatar_key(avatar_id)
    assert storage.objects[avatar_key(avatar_id)] == (b"new-jpeg", "image/jpeg")

    # The public endpoint serves the copy; anything else is a 404.
    app = create_app(settings)
    with TestClient(app, base_url="https://testserver") as client:
        app.state.rate_limiter = InMemoryRateLimiter()
        app.state.minio = storage
        response = client.get(f"/v1/public/creator-avatars/{avatar_id}")
        assert response.status_code == 200
        assert response.content == b"new-jpeg"
        assert response.headers["content-type"] == "image/jpeg"
        assert "max-age" in response.headers["cache-control"]
        assert client.get("/v1/public/creator-avatars/../secret").status_code == 404
        assert client.get(f"/v1/public/creator-avatars/{uuid.uuid4().hex}").status_code == 404
        storage.objects[avatar_key("f" * 32)] = (b"<svg/>", "image/svg+xml")
        assert client.get(f"/v1/public/creator-avatars/{'f' * 32}").status_code == 404


def test_failed_copy_keeps_raw_url_and_retries_within_the_hour(tmp_path) -> None:
    settings = _settings(tmp_path)
    _, watch_id = asyncio.run(_seed(settings))

    async def run() -> Watch:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                cache = CreatorAvatarCache(session, settings, _Storage(), lambda url: None, None)
                await cache.refresh_due(now=NOW)
                # Not due again a few minutes later, but due after an hour.
                assert await cache.refresh_due(now=NOW + timedelta(minutes=5)) == 0
                watch = await session.get(Watch, watch_id)
                assert watch is not None
                return watch
        finally:
            await database.close()

    watch = asyncio.run(run())
    assert watch.creator_avatar_key is None
    # No copy yet: clients get no URL and show initials (TikTok's CDN URL is
    # never passed on).
    assert watch_response(watch).creator.avatar_url is None
    refreshed = watch.creator_avatar_refreshed_at
    assert refreshed is not None
    retry_at = refreshed.replace(tzinfo=timezone.utc) + timedelta(
        hours=settings.creator_avatar_refresh_hours
    )
    assert NOW < retry_at <= NOW + timedelta(hours=1)


def test_cache_is_off_without_a_public_api_origin(tmp_path) -> None:
    settings = replace(_settings(tmp_path), public_api_base_url="")
    asyncio.run(_seed(settings))

    async def run() -> int:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                return await CreatorAvatarCache(
                    session, settings, _Storage(), lambda url: (b"x", "image/jpeg")
                ).refresh_due(now=NOW)
        finally:
            await database.close()

    assert asyncio.run(run()) == 0


def test_only_tiktok_image_cdn_urls_are_downloaded() -> None:
    assert avatar_url_allowed(OLD_CDN)
    assert avatar_url_allowed("https://p77-sign.tiktokcdn-us.com/a.webp")
    assert not avatar_url_allowed("http://p16-sign-va.tiktokcdn.com/a.jpeg")
    assert not avatar_url_allowed("https://evil.example/tiktokcdn.com.jpeg")
    assert not avatar_url_allowed("https://169.254.169.254/latest/meta-data")


def test_recordings_get_the_avatar_of_their_owners_watch(tmp_path) -> None:
    settings = _settings(tmp_path)
    user_id, watch_id = asyncio.run(_seed(settings))

    async def run() -> dict[uuid.UUID, str]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                watch = await session.get(Watch, watch_id)
                assert watch is not None
                watch.creator_avatar_cached_url = "https://api.savestream.test/v1/public/creator-avatars/x"
                other = User(email="b@example.com", normalized_email="b@example.com", role="user")
                session.add(other)
                await session.flush()
                mine = Recording(
                    user_id=user_id,
                    source_type="username",
                    source_value="p.c.dat25",
                    resolved_username="P.C.DAT25",
                    status="completed",
                    quality="best",
                    container="mp4",
                )
                theirs = Recording(
                    user_id=other.id,
                    source_type="username",
                    source_value="p.c.dat25",
                    resolved_username="p.c.dat25",
                    status="completed",
                    quality="best",
                    container="mp4",
                )
                session.add_all([mine, theirs])
                await session.commit()
                urls = await recording_avatar_urls(session, [mine, theirs])
                assert theirs.id not in urls  # never another user's watch
                return {mine.id: urls[mine.id]}
        finally:
            await database.close()

    assert list(asyncio.run(run()).values()) == [
        "https://api.savestream.test/v1/public/creator-avatars/x"
    ]


def test_deleting_a_channel_removes_its_avatar_copy(tmp_path) -> None:
    settings = _settings(tmp_path)
    _, watch_id = asyncio.run(_seed(settings))
    storage = _Storage()

    async def run() -> Watch:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                cache = CreatorAvatarCache(
                    session, settings, storage, lambda url: (b"jpeg", "image/jpeg")
                )
                await cache.refresh_due(now=NOW)
                watch = await session.get(Watch, watch_id)
                assert watch is not None and watch.creator_avatar_key in storage.objects
                watch.deleted_at = NOW  # any deletion path (user, account, admin)
                await session.commit()
                assert await cache.remove_deleted() == 1
                await session.refresh(watch)
                return watch
        finally:
            await database.close()

    watch = asyncio.run(run())
    assert storage.objects == {}
    assert watch.creator_avatar_key is None
    assert watch.creator_avatar_cached_url is None


def test_a_new_channel_gets_its_avatar_copy_right_away(tmp_path, monkeypatch) -> None:
    from types import SimpleNamespace

    from app.api.routes import watches as watch_routes

    settings = _settings(tmp_path)
    _, watch_id = asyncio.run(_seed(settings))
    storage = _Storage()
    monkeypatch.setattr(watch_routes, "download_avatar", lambda url: (b"jpeg", "image/jpeg"))

    async def run() -> Watch:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                watch = await session.get(Watch, watch_id)
                assert watch is not None
                request = SimpleNamespace(app=SimpleNamespace(state=SimpleNamespace(minio=storage)))
                service = SimpleNamespace(session=session, settings=settings)
                await watch_routes._copy_avatar_now(request, service, watch)  # type: ignore[arg-type]
                await session.refresh(watch)
                return watch
        finally:
            await database.close()

    watch = asyncio.run(run())
    assert watch.creator_avatar_key in storage.objects
    assert watch_response(watch).creator.avatar_url == watch.creator_avatar_cached_url
    assert watch.creator_avatar_cached_url.startswith(
        "https://api.savestream.test/v1/public/creator-avatars/"
    )


def test_lookup_avatar_copy_is_ours_and_keyed(tmp_path) -> None:
    from app.application.creators.avatar_cache import cache_lookup_avatar, lookup_avatar_id

    settings = _settings(tmp_path)
    storage = _Storage()
    url = asyncio.run(
        cache_lookup_avatar(
            settings,
            storage,
            lambda u: (b"jpeg", "image/jpeg"),
            username="P.C.Dat25",
            source_url=NEW_CDN,
        )
    )
    avatar_id = lookup_avatar_id(settings, "p.c.dat25")
    assert url == f"https://api.savestream.test/v1/public/creator-avatars/{avatar_id}"
    assert list(storage.objects) == [avatar_key(avatar_id)]
    # Not derivable from the handle without the server secret.
    other = replace(settings, jwt_secret="another-secret")
    assert lookup_avatar_id(other, "p.c.dat25") != avatar_id
    # Nothing to copy, or the download fails: no URL (initials).
    assert asyncio.run(
        cache_lookup_avatar(settings, storage, lambda u: None, username="x", source_url=NEW_CDN)
    ) is None
    assert asyncio.run(
        cache_lookup_avatar(settings, storage, lambda u: None, username="x", source_url=None)
    ) is None


def test_notifications_get_the_avatar_of_the_users_own_channel(tmp_path) -> None:
    from app.application.creators.avatar_cache import notification_avatar_urls

    settings = _settings(tmp_path)
    user_id, watch_id = asyncio.run(_seed(settings))
    cached = "https://api.savestream.test/v1/public/creator-avatars/" + "a" * 32

    async def run() -> dict[uuid.UUID, str]:
        database = Database(settings.database_url)
        try:
            async with database.session() as session:
                watch = await session.get(Watch, watch_id)
                assert watch is not None
                watch.creator_avatar_cached_url = cached
                recording = Recording(
                    user_id=user_id,
                    source_type="username",
                    source_value="p.c.dat25",
                    resolved_username="p.c.dat25",
                    status="completed",
                    quality="best",
                    container="mp4",
                )
                session.add(recording)
                await session.commit()
                ids = [uuid.uuid4() for _ in range(5)]
                found = await notification_avatar_urls(
                    session,
                    user_id,
                    [
                        (ids[0], "watch", str(watch_id)),
                        (ids[1], "recording", str(recording.id)),
                        (ids[2], "broadcast", None),
                        (ids[3], "watch", "not-a-uuid"),
                        (ids[4], "watch", str(uuid.uuid4())),
                    ],
                )
                # Another user never gets this user's channel picture.
                assert await notification_avatar_urls(
                    session, uuid.uuid4(), [(ids[0], "watch", str(watch_id))]
                ) == {}
                return {ids.index(key): value for key, value in found.items()}
        finally:
            await database.close()

    assert asyncio.run(run()) == {0: cached, 1: cached}
