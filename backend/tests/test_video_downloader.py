"""Public video downloader: link safety, permission gate, limits, streaming.

Everything runs against fake providers, a fake Redis and httpx mock
transports; nothing talks to TikTok.
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import replace
from typing import Any

import httpx
import pytest
from fastapi.testclient import TestClient

from app.downloader import links
from app.downloader.app import build_service, create_app
from app.downloader.chain import (
    CircuitBreaker,
    DownloadsDisabled,
    PermissionUnknown,
    ProviderChain,
)
from app.downloader.config import DownloaderSettings
from app.downloader.media import is_allowed_media_url
from app.downloader.providers.base import MediaSource, ProviderError, VideoInfo, VideoUnavailable
from app.downloader.providers.page import parse_item
from app.downloader.providers.ytdlp import parse_info
from app.downloader.state import BLOCKLIST_KEY, BLOCKLIST_SYNCED_KEY

VIDEO_ID = "7702676085506411809"
PAGE_URL = f"https://www.tiktok.com/@shop.live/video/{VIDEO_ID}"
DOWNLOAD_URL = "https://v16-webapp-prime.us.tiktok.com/video/tos/download.mp4"
PLAY_URL = "https://v16-webapp-prime.us.tiktok.com/video/tos/play.mp4"
COVER_URL = "https://p16-sign.tiktokcdn-us.com/cover.jpeg"


class FakeRedis:
    def __init__(self) -> None:
        self.values: dict[str, Any] = {}
        self.sets: dict[str, set[str]] = {}
        self.expiry: dict[str, int] = {}

    async def get(self, name: str) -> Any:
        return self.values.get(name)

    async def set(self, name: str, value: Any, ex: int | None = None) -> bool:
        self.values[name] = value
        if ex:
            self.expiry[name] = ex
        return True

    async def incr(self, name: str) -> int:
        self.values[name] = int(self.values.get(name, 0)) + 1
        return int(self.values[name])

    async def expire(self, name: str, time: int) -> bool:
        self.expiry[name] = time
        return True

    async def ttl(self, name: str) -> int:
        return self.expiry.get(name, -1)

    async def sismember(self, name: str, value: str) -> bool:
        return value in self.sets.get(name, set())

    async def exists(self, *names: str) -> int:
        return sum(1 for n in names if n in self.values or n in self.sets)


def _info(**changes: Any) -> VideoInfo:
    base = VideoInfo(
        video_id=VIDEO_ID,
        username="shop.live",
        author_name="Shop Live",
        caption="Today's drop",
        duration_seconds=102,
        posted_at=None,
        videos=(
            MediaSource(url=PLAY_URL, height=1024, size_bytes=9_000_000),
            MediaSource(url=DOWNLOAD_URL, height=720, size_bytes=10_000_000, watermarked=True),
        ),
        audio=None,
        cover=MediaSource(url=COVER_URL, extension="jpg"),
        provider="page",
        download_allowed=True,
    )
    return replace(base, **changes)


class FakeProvider:
    def __init__(self, name: str, result: Any) -> None:
        self.name = name
        self.result = result
        self.calls = 0

    async def resolve(self, url: str, *, video_id: str, timeout: float) -> VideoInfo:
        self.calls += 1
        if isinstance(self.result, Exception):
            raise self.result
        return self.result


def _chain(*providers: FakeProvider) -> ProviderChain:
    return ProviderChain(list(providers), {p.name: 1.0 for p in providers})


# --- links ---------------------------------------------------------------


def test_links_accept_only_single_tiktok_videos() -> None:
    link = links.parse_link(f"{PAGE_URL}?is_from_webapp=1")
    assert (link.video_id, link.username, link.url) == (VIDEO_ID, "shop.live", PAGE_URL)
    assert links.parse_link(f"www.tiktok.com./@shop.live/video/{VIDEO_ID}").video_id == VIDEO_ID
    assert links.parse_link("https://vm.tiktok.com/ZMabc123/").is_short
    assert links.parse_link("https://www.tiktok.com/t/ZTabc123/").is_short
    for bad in (
        "https://evil.example/@a/video/123456789",
        f"https://user:pw@www.tiktok.com/@a/video/{VIDEO_ID}",
        f"https://www.tiktok.com:8443/@a/video/{VIDEO_ID}",
        "https://www.tiktok.com/@shop.live",
        "https://tiktok.com.evil.example/@a/video/1234567890",
        "javascript:alert(1)",
        "",
        "https://www.tiktok.com/@a/video/" + "1" * 3000,
    ):
        with pytest.raises(links.InvalidLink):
            links.parse_link(bad)


def test_short_links_follow_only_tiktok_redirects() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "vm.tiktok.com":
            return httpx.Response(301, headers={"location": "https://www.tiktok.com/t/ZTx1234/"})
        if request.url.path.startswith("/t/"):
            return httpx.Response(302, headers={"location": f"/@shop.live/video/{VIDEO_ID}?x=1"})
        return httpx.Response(200)

    async def run() -> None:
        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as client:
            link = await links.expand(links.parse_link("vm.tiktok.com/ZMabc123"), client)
            assert link.url == PAGE_URL

        def evil(request: httpx.Request) -> httpx.Response:
            return httpx.Response(302, headers={"location": "http://169.254.169.254/latest"})

        async with httpx.AsyncClient(transport=httpx.MockTransport(evil)) as client:
            with pytest.raises(links.InvalidLink):
                await links.expand(links.parse_link("vm.tiktok.com/ZMabc123"), client)

        def loop(request: httpx.Request) -> httpx.Response:
            return httpx.Response(302, headers={"location": "https://vt.tiktok.com/ZMloop1/"})

        async with httpx.AsyncClient(transport=httpx.MockTransport(loop)) as client:
            with pytest.raises(links.InvalidLink):
                await links.expand(links.parse_link("vm.tiktok.com/ZMabc123"), client)

    asyncio.run(run())


def test_media_hosts_are_tiktok_cdns_only() -> None:
    assert is_allowed_media_url(DOWNLOAD_URL)
    assert is_allowed_media_url(COVER_URL)
    for bad in (
        "http://v16-webapp-prime.us.tiktok.com/a.mp4",
        "https://www.tiktok.com/@a/video/1",
        "https://evil.example/a.mp4",
        "https://tiktokcdn.com.evil.example/a.mp4",
        "https://u:p@v16.tiktokcdn.com/a.mp4",
        "https://v16.tiktokcdn.com:8443/a.mp4",
        "file:///etc/passwd",
    ):
        assert not is_allowed_media_url(bad), bad


# --- providers -----------------------------------------------------------


def _item(**changes: Any) -> dict[str, Any]:
    item: dict[str, Any] = {
        "id": VIDEO_ID,
        "desc": "Today's drop",
        "createTime": "1730000000",
        "author": {"id": "7012345", "uniqueId": "shop.live", "nickname": "Shop", "downloadSetting": 0},
        "video": {
            "duration": 102,
            "width": 576,
            "height": 1024,
            "playAddr": PLAY_URL,
            "downloadAddr": DOWNLOAD_URL,
            "cover": COVER_URL,
        },
    }
    item.update(changes)
    return item


def test_page_provider_reads_the_creators_download_setting() -> None:
    info = parse_item(_item(), video_id=VIDEO_ID, headers={}, provider="page")
    assert info.download_allowed is True
    assert info.author_id == "7012345"
    assert [s.url for s in info.videos if s.watermarked] == [DOWNLOAD_URL]

    off = _item(author={"uniqueId": "shop.live", "downloadSetting": 3})
    assert parse_item(off, video_id=VIDEO_ID, headers={}, provider="page").download_allowed is False
    unknown = _item(author={"uniqueId": "shop.live"})
    assert parse_item(unknown, video_id=VIDEO_ID, headers={}, provider="page").download_allowed is None

    for private in (
        _item(privateItem=True),
        _item(secret=True),
        _item(author={"uniqueId": "x", "privateAccount": True, "downloadSetting": 0}),
    ):
        with pytest.raises(VideoUnavailable) as exc:
            parse_item(private, video_id=VIDEO_ID, headers={}, provider="page")
        assert exc.value.reason == "private"


def test_ytdlp_marks_tiktoks_download_format_as_the_watermarked_file() -> None:
    info = parse_info(
        {
            "id": VIDEO_ID,
            "uploader": "shop.live",
            "formats": [
                {"format_id": "h264_540p", "url": PLAY_URL, "vcodec": "h264", "height": 1024},
                {"format_id": "download", "url": DOWNLOAD_URL, "vcodec": "h264", "format_note": "watermarked"},
            ],
        },
        video_id=VIDEO_ID,
        cookies={"tt_chain_token": "abc"},
        provider="ytdlp",
    )
    assert info.download_allowed is None
    assert [s.url for s in info.videos if s.watermarked] == [DOWNLOAD_URL]
    assert info.videos[0].headers["Cookie"] == "tt_chain_token=abc"


# --- chain ---------------------------------------------------------------


def test_public_mode_serves_only_the_watermarked_file_of_allowed_videos() -> None:
    page = FakeProvider("page", _info())
    ytdlp = FakeProvider("ytdlp", _info(provider="ytdlp", download_allowed=None))
    resolved = asyncio.run(_chain(page, ytdlp).resolve(PAGE_URL, video_id=VIDEO_ID, mode="public"))
    assert [f.url for f in resolved.files] == [DOWNLOAD_URL]
    assert ytdlp.calls == 0


def test_public_mode_refuses_downloads_off_and_unknown_permission() -> None:
    with pytest.raises(DownloadsDisabled):
        asyncio.run(
            _chain(FakeProvider("page", _info(download_allowed=False))).resolve(
                PAGE_URL, video_id=VIDEO_ID, mode="public"
            )
        )
    # yt-dlp cannot read the setting: without the page provider we refuse.
    chain = _chain(
        FakeProvider("page", ProviderError("blocked")),
        FakeProvider("ytdlp", _info(download_allowed=None)),
    )
    with pytest.raises(PermissionUnknown):
        asyncio.run(chain.resolve(PAGE_URL, video_id=VIDEO_ID, mode="public"))


def test_public_mode_uses_ytdlp_file_when_page_confirms_permission() -> None:
    page_only_play = _info(videos=(MediaSource(url=PLAY_URL),))
    ytdlp_file = _info(provider="ytdlp", download_allowed=None)
    resolved = asyncio.run(
        _chain(FakeProvider("page", page_only_play), FakeProvider("ytdlp", ytdlp_file)).resolve(
            PAGE_URL, video_id=VIDEO_ID, mode="public"
        )
    )
    assert [f.url for f in resolved.files] == [DOWNLOAD_URL]
    assert resolved.info.download_allowed is True


def test_private_or_removed_stops_the_chain() -> None:
    ytdlp = FakeProvider("ytdlp", _info())
    chain = _chain(FakeProvider("page", VideoUnavailable("removed")), ytdlp)
    with pytest.raises(VideoUnavailable):
        asyncio.run(chain.resolve(PAGE_URL, video_id=VIDEO_ID, mode="public"))
    assert ytdlp.calls == 0


def test_owner_mode_ignores_the_setting_and_offers_the_clean_stream() -> None:
    resolved = asyncio.run(
        _chain(FakeProvider("page", _info(download_allowed=False))).resolve(
            PAGE_URL, video_id=VIDEO_ID, mode="owner"
        )
    )
    assert [f.url for f in resolved.files] == [PLAY_URL, DOWNLOAD_URL]


def test_circuit_breaker_skips_a_failing_provider() -> None:
    breaker = CircuitBreaker(threshold=2, window=60, cooldown=30)
    now = time.monotonic()
    breaker.failure(now)
    assert breaker.allow(now)
    breaker.failure(now + 1)
    assert not breaker.allow(now + 2)
    assert breaker.allow(now + 32)

    failing = FakeProvider("page", ProviderError("down"))
    chain = _chain(failing, FakeProvider("ytdlp", _info(download_allowed=None)))
    chain.breakers["page"] = CircuitBreaker(threshold=1, window=60, cooldown=300)
    for _ in range(3):
        with pytest.raises(PermissionUnknown):
            asyncio.run(chain.resolve(PAGE_URL, video_id=VIDEO_ID, mode="public"))
    assert failing.calls == 1


# --- service and HTTP ----------------------------------------------------


def _settings(**changes: Any) -> DownloaderSettings:
    values: dict[str, Any] = {"flag_enabled": True, "turnstile_secret_key": "ts-secret"}
    values.update(changes)
    return DownloaderSettings(**values)


def _media_handler(body: bytes = b"x" * 1000, status: int = 200) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host.endswith("tiktokcdn-us.com"):
            return httpx.Response(200, content=b"jpeg", headers={"content-type": "image/jpeg"})
        return httpx.Response(
            status, content=body, headers={"content-type": "video/mp4", "content-length": str(len(body))}
        )

    return httpx.MockTransport(handler)


def _client(
    settings: DownloaderSettings,
    *,
    redis: FakeRedis | None = None,
    chain: ProviderChain | None = None,
    transport: httpx.MockTransport | None = None,
    turnstile_ok: bool = True,
) -> tuple[TestClient, FakeRedis]:
    redis = redis or FakeRedis()
    redis.values.setdefault(BLOCKLIST_SYNCED_KEY, "1")

    async def turnstile(token: str, ip: str) -> bool:
        return turnstile_ok and token == "good"

    service = build_service(
        settings,
        redis=redis,
        http=httpx.AsyncClient(transport=transport or _media_handler()),
        chain=chain or _chain(FakeProvider("page", _info())),
        turnstile=turnstile,
    )
    return TestClient(create_app(settings, service=service)), redis


def test_flag_off_and_production_without_proxy_stay_disabled() -> None:
    assert not DownloaderSettings().enabled
    guarded = DownloaderSettings(flag_enabled=True, environment="production")
    assert not guarded.enabled and guarded.guard_blocked
    assert DownloaderSettings(flag_enabled=True, environment="production", proxy_url="http://p:1").enabled

    client, _ = _client(_settings(flag_enabled=False))
    assert client.get("/v1/public/video-downloader/status").json()["enabled"] is False
    response = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "DOWNLOADER_DISABLED"


def test_resolve_and_stream_the_allowed_file() -> None:
    client, redis = _client(_settings())
    response = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["video"]["downloads_allowed_by_creator"] is True
    assert [f["watermarked"] for f in body["files"]] == [True]
    assert response.headers["cache-control"] == "no-store"
    # Nothing but short-lived Redis entries is kept.
    assert all(k.startswith("savestream:video_downloader:") for k in redis.values)

    download = client.get(body["files"][0]["download_url"])
    assert download.status_code == 200
    assert download.content == b"x" * 1000
    assert download.headers["content-disposition"] == (
        f'attachment; filename="tiktok-shop.live-{VIDEO_ID}.mp4"'
    )
    cover = client.get(body["video"]["cover_url"])
    assert cover.status_code == 200 and cover.content == b"jpeg"


def test_resolve_refusals() -> None:
    cases = [
        (_chain(FakeProvider("page", _info(download_allowed=False))), 403, "DOWNLOADS_DISABLED"),
        (_chain(FakeProvider("page", VideoUnavailable("private"))), 404, "VIDEO_UNAVAILABLE"),
        (_chain(FakeProvider("page", _info(duration_seconds=601))), 413, "VIDEO_TOO_LONG"),
        (_chain(FakeProvider("page", ProviderError("x"))), 503, "DOWNLOADER_UNAVAILABLE"),
    ]
    for chain, status, code in cases:
        client, _ = _client(_settings(), chain=chain)
        response = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
        assert (response.status_code, response.json()["error"]["code"]) == (status, code)

    client, _ = _client(_settings())
    response = client.post("/v1/public/video-downloader/resolve", json={"url": "https://youtube.com/x"})
    assert response.json()["error"]["code"] == "INVALID_LINK"


def test_reported_videos_and_unsynced_blocklist_are_refused() -> None:
    redis = FakeRedis()
    redis.sets[BLOCKLIST_KEY] = {VIDEO_ID}
    client, _ = _client(_settings(), redis=redis)
    response = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
    assert (response.status_code, response.json()["error"]["code"]) == (451, "VIDEO_BLOCKED")

    client, redis = _client(_settings())
    del redis.values[BLOCKLIST_SYNCED_KEY]
    response = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
    assert response.status_code == 503

    # Blocked after the link was handed out: the download is refused too.
    client, redis = _client(_settings())
    url = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL}).json()[
        "files"
    ][0]["download_url"]
    redis.sets[BLOCKLIST_KEY] = {VIDEO_ID}
    assert client.get(url).status_code == 451


def test_turnstile_after_five_and_hard_stop_after_ten() -> None:
    client, _ = _client(_settings())
    endpoint = "/v1/public/video-downloader/resolve"
    for i in range(5):
        body = client.post(endpoint, json={"url": PAGE_URL}).json()
        assert body["turnstile_required_next"] is (i == 4)
    sixth = client.post(endpoint, json={"url": PAGE_URL})
    assert sixth.json()["error"]["code"] == "CAPTCHA_REQUIRED"
    # The failed attempt counted as the 6th; four more with Turnstile make 10.
    for _ in range(4):
        assert client.post(endpoint, json={"url": PAGE_URL, "turnstile_token": "good"}).status_code == 200
    limited = client.post(endpoint, json={"url": PAGE_URL, "turnstile_token": "good"})
    assert limited.status_code == 429
    assert limited.json()["error"]["details"]["retry_after_seconds"] == 3600
    assert limited.headers["retry-after"] == "3600"

    # Without a Turnstile secret there is no second tier.
    client, _ = _client(_settings(turnstile_secret_key=""))
    for _ in range(5):
        assert client.post(endpoint, json={"url": PAGE_URL}).status_code == 200
    assert client.post(endpoint, json={"url": PAGE_URL}).status_code == 429


def test_download_links_are_tied_to_the_ip_and_capped() -> None:
    client, _ = _client(_settings())
    url = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL}).json()["files"][0][
        "download_url"
    ]
    other = TestClient(client.app, client=("203.0.113.9", 5000))
    moved = other.get(url, follow_redirects=False)
    assert moved.status_code == 303
    assert moved.headers["location"] == "https://savestream.online/video-downloader?expired=1"
    assert client.get("/v1/public/video-downloader/file/nope", follow_redirects=False).status_code == 303

    small, _ = _client(_settings(max_bytes=500))
    small_chain_url = small.post(
        "/v1/public/video-downloader/resolve", json={"url": PAGE_URL}
    )
    # The advertised size (10 MB) is over the cap, so no file is offered.
    assert small_chain_url.status_code == 413

    capped, _ = _client(
        _settings(max_bytes=500),
        chain=_chain(FakeProvider("page", _info(videos=(MediaSource(url=DOWNLOAD_URL, watermarked=True),)))),
    )
    url = capped.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL}).json()["files"][0][
        "download_url"
    ]
    response = capped.get(url)
    assert response.status_code == 413  # Content-Length says 1000 bytes


def test_concurrent_stream_cap() -> None:
    settings = _settings(max_streams=1)
    client, _ = _client(settings)
    url = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL}).json()["files"][0][
        "download_url"
    ]
    with client:
        service = client.app.state.service
        asyncio.run(service.streams.acquire())
        busy = client.get(url)
        assert (busy.status_code, busy.json()["error"]["code"]) == (503, "DOWNLOADER_BUSY")
        service.streams.release()
        assert client.get(url).status_code == 200


def test_non_tiktok_media_is_never_fetched() -> None:
    evil = _info(videos=(MediaSource(url="https://evil.example/x.mp4", watermarked=True),))
    client, _ = _client(_settings(), chain=_chain(FakeProvider("page", evil)))
    url = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL}).json()["files"][0][
        "download_url"
    ]
    assert client.get(url).status_code == 503


def test_cors_lets_the_website_read_errors_and_retry_after() -> None:
    client, _ = _client(_settings(cors_allow_origins=("https://savestream.online",)))
    preflight = client.options(
        "/v1/public/video-downloader/resolve",
        headers={
            "Origin": "https://savestream.online",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "content-type",
        },
    )
    assert preflight.status_code == 200
    # The website's API client adds X-Request-ID (and Authorization when
    # signed in) to every request, including the status check.
    for headers in ("x-request-id", "authorization,content-type,x-request-id"):
        web = client.options(
            "/v1/public/video-downloader/status",
            headers={
                "Origin": "https://savestream.online",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": headers,
            },
        )
        assert web.status_code == 200, headers
    assert preflight.headers["access-control-allow-origin"] == "https://savestream.online"
    response = client.post(
        "/v1/public/video-downloader/resolve",
        json={"url": PAGE_URL},
        headers={"Origin": "https://savestream.online"},
    )
    assert "Retry-After" in response.headers["access-control-expose-headers"]
    evil = client.options(
        "/v1/public/video-downloader/resolve",
        headers={"Origin": "https://evil.example", "Access-Control-Request-Method": "POST"},
    )
    assert "access-control-allow-origin" not in evil.headers
