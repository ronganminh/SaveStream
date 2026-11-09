"""Owner downloads: grants signed by the API, verified by the downloader."""

from __future__ import annotations

import asyncio
import time
import uuid
from dataclasses import replace

import pytest

from app.application.video_downloader.owner import issue_grant
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.downloader import grants
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.db.watch_models import Watch
from app.infrastructure.rate_limit import InMemoryRateLimiter
from tests.identity_helpers import identity_settings
from tests.test_video_downloader import (
    PAGE_URL,
    VIDEO_ID,
    FakeProvider,
    _chain,
    _client,
    _info,
    _settings,
)

SECRET = "grant-secret"


def test_grants_are_signed_short_lived_and_tamper_proof() -> None:
    token = grants.issue(SECRET, user_id="u1", usernames=["@Shop.Live"], tiktok_ids=["701"])
    grant = grants.verify(SECRET, token)
    assert grant.user_id == "u1"
    assert grant.owns(username="shop.live", tiktok_id=None)
    assert grant.owns(username="renamed", tiktok_id="701")
    assert not grant.owns(username="other", tiktok_id="702")
    for bad in (None, "", "x", token[:-2] + "aa", token.replace(".", "x.", 1)):
        with pytest.raises(grants.InvalidGrant):
            grants.verify(SECRET, bad)
    with pytest.raises(grants.InvalidGrant):
        grants.verify("other-secret", token)
    old = grants.issue(SECRET, user_id="u1", usernames=["a"], tiktok_ids=[], now=time.time() - 120)
    with pytest.raises(grants.InvalidGrant):
        grants.verify(SECRET, old)
    with pytest.raises(grants.InvalidGrant):
        grants.issue("", user_id="u1", usernames=["a"], tiktok_ids=[])


def test_api_grants_only_cover_verified_unblocked_channels(tmp_path) -> None:
    settings = replace(
        identity_settings(f"sqlite+aiosqlite:///{tmp_path / 'owner.db'}"),
        video_downloader_enabled=True,
        video_downloader_grant_secret=SECRET,
    )

    async def run() -> None:
        database = Database(settings.database_url)
        async with database.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)
        try:
            async with database.session() as session:
                user = User(email="o@example.com", normalized_email="o@example.com", role="user")
                session.add(user)
                await session.flush()
                now = time.time()
                from datetime import datetime, timezone

                ts = datetime.fromtimestamp(now, tz=timezone.utc)

                def watch(name: str, **extra) -> Watch:
                    return Watch(
                        user_id=user.id,
                        source_type="username",
                        source_value=name,
                        resolved_username=name,
                        status="active",
                        live_status="unknown",
                        **extra,
                    )

                session.add_all(
                    [
                        watch("shop.live", owner_verified_at=ts, owner_verified_tiktok_id="701"),
                        watch("unverified"),
                        watch("blocked.one", owner_verified_at=ts, blocked_at=ts),
                        watch("deleted.one", owner_verified_at=ts, deleted_at=ts),
                    ]
                )
                await session.commit()
                web = AuthPrincipal(user.id, uuid.uuid4(), "user", scopes_for_role("user"))
                app = replace(web, client_type="mobile")
                limiter = InMemoryRateLimiter()

                token = await issue_grant(session, settings, limiter, web, PAGE_URL)
                grant = grants.verify(SECRET, token)
                assert grant.user_id == str(user.id)
                assert grant.usernames == frozenset({"shop.live"})
                assert grant.tiktok_ids == frozenset({"701"})
                # Short links are checked by the downloader after resolving.
                await issue_grant(session, settings, limiter, web, "https://vm.tiktok.com/ZMabc12/")

                async def code(principal: AuthPrincipal, url: str, cfg=settings) -> str:
                    with pytest.raises(ApplicationError) as exc:
                        await issue_grant(session, cfg, limiter, principal, url)
                    return exc.value.code

                other = f"https://www.tiktok.com/@blocked.one/video/{VIDEO_ID}"
                assert await code(web, other) == "NOT_YOUR_CHANNEL"
                assert await code(web, "https://youtube.com/x") == "INVALID_LINK"
                assert await code(app, PAGE_URL) == "WEB_ONLY"
                off = replace(settings, video_downloader_enabled=False)
                assert await code(web, PAGE_URL, off) == "DOWNLOADER_DISABLED"
                stranger = AuthPrincipal(uuid.uuid4(), uuid.uuid4(), "user", scopes_for_role("user"))
                assert await code(stranger, PAGE_URL) == "NO_VERIFIED_CHANNEL"
        finally:
            await database.close()

    asyncio.run(run())


def _owner_client(**chain_info):
    settings = _settings(grant_secret=SECRET)
    chain = _chain(FakeProvider("page", _info(download_allowed=False, author_id="701", **chain_info)))
    client, redis = _client(settings, chain=chain)
    return client


def _grant(user: str = "u1", names: tuple[str, ...] = ("shop.live",), ids: tuple[str, ...] = ()) -> str:
    return grants.issue(SECRET, user_id=user, usernames=list(names), tiktok_ids=list(ids))


def test_owner_can_download_own_video_even_with_downloads_off() -> None:
    client = _owner_client()
    response = client.post(
        "/v1/public/video-downloader/owner/resolve", json={"url": PAGE_URL, "grant": _grant()}
    )
    assert response.status_code == 200, response.text
    files = response.json()["files"]
    assert [(f["label"], f["watermarked"]) for f in files] == [
        ("Original", False),
        ("MP4 (TikTok download)", True),
    ]
    url = files[0]["download_url"]
    assert url.startswith("/v1/public/video-downloader/owner/file/")

    # Every file request needs a fresh grant for the same user and channel.
    ok = client.get(url, params={"grant": _grant()})
    assert ok.status_code == 200 and ok.content == b"x" * 1000
    assert client.get(url, params={"grant": _grant(user="u2")}).status_code == 403
    assert client.get(url, params={"grant": _grant(names=("someone.else",))}).status_code == 403
    expired = client.get(url, follow_redirects=False)
    assert expired.headers["location"].endswith("/my-videos?expired=1")
    # Owner links are not public links: without a grant they are refused.
    assert client.get(url.replace("/owner/file/", "/file/"), follow_redirects=False).status_code == 403


def test_owner_resolve_refusals() -> None:
    client = _owner_client()
    endpoint = "/v1/public/video-downloader/owner/resolve"
    not_mine = client.post(endpoint, json={"url": PAGE_URL, "grant": _grant(names=("other",))})
    assert not_mine.json()["error"]["code"] == "NOT_YOUR_CHANNEL"
    # Matched by the verified TikTok account id even if the handle changed.
    renamed = client.post(
        endpoint, json={"url": PAGE_URL, "grant": _grant(names=("shop.live",), ids=("701",))}
    )
    assert renamed.status_code == 200
    bad = client.post(endpoint, json={"url": PAGE_URL, "grant": "forged.grant"})
    assert bad.json()["error"]["code"] == "GRANT_INVALID"

    # The author check uses the resolved video, not just the link.
    impostor = _owner_client(username="someone.else")
    response = impostor.post(endpoint, json={"url": PAGE_URL, "grant": _grant()})
    assert response.json()["error"]["code"] == "NOT_YOUR_CHANNEL"


def test_public_mode_still_refuses_the_same_video() -> None:
    client = _owner_client()
    response = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
    assert response.json()["error"]["code"] == "DOWNLOADS_DISABLED"

