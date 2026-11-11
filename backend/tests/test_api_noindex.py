"""api.savestream.online stays out of search engines: every response carries
X-Robots-Tag and /robots.txt disallows everything (API and downloader)."""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.api.robots import ROBOTS_TXT, X_ROBOTS_TAG
from app.main import create_app
from tests.identity_helpers import create_schema, identity_settings
from tests.test_video_downloader import PAGE_URL, _client, _settings


def _api(tmp_path) -> TestClient:
    url = f"sqlite+aiosqlite:///{tmp_path / 'noindex.db'}"
    create_schema(url)
    app = create_app(identity_settings(url))

    @app.get("/__test/boom")
    async def boom() -> None:
        raise RuntimeError("unhandled")

    return TestClient(app, base_url="https://testserver", raise_server_exceptions=False)


def test_every_api_response_is_noindex(tmp_path) -> None:
    with _api(tmp_path) as client:
        responses = {
            "ok": client.get("/health/live"),
            "not found": client.get("/v1/does-not-exist"),
            "validation": client.post("/v1/public/reports", json={"kind": "nope"}),
            "unauthorized": client.get("/v1/me"),
            "unhandled 500": client.get("/__test/boom"),
        }
        robots = client.get("/robots.txt")
    for name, response in responses.items():
        assert response.headers.get("x-robots-tag") == X_ROBOTS_TAG, name
    assert responses["unhandled 500"].status_code == 500
    assert robots.status_code == 200
    assert robots.text == ROBOTS_TXT == "User-agent: *\nDisallow: /\n"
    assert robots.headers["content-type"].startswith("text/plain")
    assert robots.headers["x-robots-tag"] == X_ROBOTS_TAG


def test_every_downloader_response_is_noindex() -> None:
    client, _ = _client(_settings())
    resolved = client.post("/v1/public/video-downloader/resolve", json={"url": PAGE_URL})
    responses = {
        "status": client.get("/v1/public/video-downloader/status"),
        "resolve": resolved,
        "file stream": client.get(resolved.json()["files"][0]["download_url"]),
        "error": client.post("/v1/public/video-downloader/resolve", json={"url": "https://x.example"}),
        "not found": client.get("/v1/public/video-downloader/nope"),
        "robots": client.get("/robots.txt"),
    }
    for name, response in responses.items():
        assert response.headers.get("x-robots-tag") == X_ROBOTS_TAG, name
    assert responses["file stream"].status_code == 200
    assert responses["robots"].text == ROBOTS_TXT
