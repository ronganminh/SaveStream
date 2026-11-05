from __future__ import annotations

import pytest

from app.application.video_downloads.urls import InvalidTikTokUrl, normalize_tiktok_url


def test_accepts_canonical_tiktok_video_url() -> None:
    url = "https://www.tiktok.com/@creator/video/1234567890123456789?is_from_webapp=1"
    assert normalize_tiktok_url(url) == url


@pytest.mark.parametrize(
    "url",
    [
        "https://example.com/@creator/video/123",
        "https://www.tiktok.com.evil.example/@creator/video/123",
        "https://user:pass@www.tiktok.com/@creator/video/123",
        "https://www.tiktok.com:8443/@creator/video/123",
        "javascript:alert(1)",
        "https://www.tiktok.com/@creator/photo/123",
        "",
    ],
)
def test_rejects_unsupported_or_unsafe_urls(url: str) -> None:
    with pytest.raises(InvalidTikTokUrl):
        normalize_tiktok_url(url)


def test_rejects_redirect_to_non_tiktok_host() -> None:
    class FakeResponse:
        is_redirect = True
        is_permanent_redirect = False
        status_code = 302
        headers = {"Location": "https://127.0.0.1/admin"}

        def close(self) -> None:
            pass

    class FakeSession:
        def get(self, *args, **kwargs):
            return FakeResponse()

    with pytest.raises(InvalidTikTokUrl):
        normalize_tiktok_url("https://vm.tiktok.com/abc/", session=FakeSession())  # type: ignore[arg-type]
