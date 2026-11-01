from __future__ import annotations

import pytest

from app.application.video_downloads.urls import normalize_tiktok_url


@pytest.mark.parametrize(
    "url",
    [
        "https://www.tiktok.com/@tramquannsatvutru/video/7696351169647561992?is_from_webapp=1&sender_device=pc",
        "https://www.tiktok.com/@pakesub3/video/7702676085506411809?is_from_webapp=1&sender_device=pc",
        "https://www.tiktok.com/@wuryhochust2026/video/7702885119203216661?is_from_webapp=1&sender_device=pc",
    ],
)
def test_user_supplied_tiktok_links_are_accepted(url: str) -> None:
    assert normalize_tiktok_url(url) == url
