"""Links to the media delivery Worker (QA 2026-10-14: the R2 S3 endpoint
answered 503 to playback range requests and the first Download)."""

from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import time
from dataclasses import replace
from urllib.parse import parse_qs, urlparse

from sqlalchemy import select

from app.api.serializers.watches import creator_avatar_url, tiktok_url_expired
from app.application.creators.avatar_cache import CreatorAvatarCache
from app.infrastructure.db.models import Base
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.storage.media_urls import (
    media_delivery_enabled,
    media_signature,
    signed_media_url,
)
from app.infrastructure.storage.minio import MinioStorageClient
from tests.identity_helpers import identity_settings

SECRET = "media-secret-for-tests-0123456789abcdef"


def _settings(**overrides):
    return replace(
        identity_settings("sqlite+aiosqlite:///:memory:"),
        media_base_url="https://media.savestream.online",
        media_signing_secret=SECRET,
        artifact_presign_seconds=900,
        **overrides,
    )


def test_signature_matches_the_worker_test_vector() -> None:
    # Same vector as services/media-worker/test/index.test.js.
    assert (
        media_signature("vector-secret", "/o/users/u/recordings/r/a.mp4", 1800000000, "YXR0YWNobWVudA")
        == "gc-9Bg0JJMjbr3677UCqL8566TEc1uAZ8qWdDAqIm-I"
    )


def test_signed_url_carries_expiry_disposition_and_a_valid_signature() -> None:
    settings = _settings()
    disposition = 'attachment; filename="p.c.dat25_2026-10-14_2127.mp4"'
    url = signed_media_url(
        settings,
        "users/u1/recordings/r1/a1.mp4",
        content_disposition=disposition,
        now=1_800_000_000,
    )
    parsed = urlparse(url)
    query = {key: values[0] for key, values in parse_qs(parsed.query).items()}
    assert f"{parsed.scheme}://{parsed.netloc}" == "https://media.savestream.online"
    assert parsed.path == "/o/users/u1/recordings/r1/a1.mp4"
    assert query["e"] == "1800000900"
    padded = query["cd"] + "=" * (-len(query["cd"]) % 4)
    assert base64.urlsafe_b64decode(padded).decode() == disposition
    expected = hmac.new(
        SECRET.encode(),
        f"{parsed.path}\n{query['e']}\n{query['cd']}".encode(),
        hashlib.sha256,
    ).digest()
    assert query["s"] == base64.urlsafe_b64encode(expected).rstrip(b"=").decode()


def test_storage_links_switch_to_the_worker_only_when_fully_configured() -> None:
    enabled = _settings()
    assert media_delivery_enabled(enabled)
    url = MinioStorageClient(enabled).presigned_get_url("users/u/recordings/r/a.mp4")
    assert url.startswith("https://media.savestream.online/o/users/u/recordings/r/a.mp4?e=")

    no_url = replace(enabled, media_base_url="")
    short_secret = replace(enabled, media_signing_secret="too-short")
    for settings in (no_url, short_secret):
        assert not media_delivery_enabled(settings)
        client = MinioStorageClient(settings)
        client.client.presigned_get_object = (  # type: ignore[method-assign]
            lambda bucket, key, **kwargs: f"https://account.r2.cloudflarestorage.com/{bucket}/{key}?X-Amz-Signature=x"
        )
        link = client.presigned_get_url("users/u/recordings/r/a.mp4")
        assert link.startswith("https://account.r2.cloudflarestorage.com/")


def test_expired_tiktok_avatar_urls_are_not_sent_to_clients() -> None:
    future = int(time.time()) + 3600
    past = int(time.time()) - 60
    fresh = f"https://p16-sign-va.tiktokcdn.com/a.jpeg?x-expires={future}&x-signature=abc"
    stale = f"https://p16-sign-va.tiktokcdn.com/a.jpeg?x-expires={past}&x-signature=abc"
    assert not tiktok_url_expired(fresh)
    assert tiktok_url_expired(stale)
    assert not tiktok_url_expired("https://example.com/a.jpeg")

    watch = Watch(creator_avatar_url=stale)
    assert creator_avatar_url(watch) is None  # initials instead of a broken image
    watch.creator_avatar_url = fresh
    # Never TikTok's CDN, even while its URL is valid: only our own copy.
    assert creator_avatar_url(watch) is None
    watch.creator_avatar_cached_url = "https://media.savestream.online/a/" + "0" * 32
    assert creator_avatar_url(watch) == watch.creator_avatar_cached_url


def test_cached_avatars_move_to_the_worker_once_enabled(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'avatars.db'}"
    api_settings = replace(
        identity_settings(database_url), public_api_base_url="https://api.savestream.online"
    )
    media_settings = replace(
        api_settings,
        media_base_url="https://media.savestream.online",
        media_signing_secret=SECRET,
    )
    avatar_id = "0123456789abcdef0123456789abcdef"

    async def run() -> list[str]:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)
            from tests.test_recording_media_download import _seed_user

            async with database.session() as session:
                user = _seed_user(session, "avatars@example.com")
                await session.commit()
                await session.refresh(user)
                session.add(
                    Watch(
                        user_id=user.id,
                        source_type="username",
                        source_value="p.c.dat25",
                        status="active",
                        creator_avatar_key=f"creator-avatars/{avatar_id}",
                        creator_avatar_cached_url=(
                            f"https://api.savestream.online/v1/public/creator-avatars/{avatar_id}"
                        ),
                    )
                )
                await session.commit()
            seen = []
            for settings in (media_settings, api_settings):
                async with database.session() as session:
                    cache = CreatorAvatarCache(session, settings, storage=None, fetch=lambda url: None)  # type: ignore[arg-type]
                    await cache._retarget_cached_urls()
                    watch = (await session.scalars(select(Watch))).one()
                    seen.append(watch.creator_avatar_cached_url)
            return seen
        finally:
            await database.close()

    assert asyncio.run(run()) == [
        f"https://media.savestream.online/a/{avatar_id}",
        f"https://api.savestream.online/v1/public/creator-avatars/{avatar_id}",
    ]
