"""Extraction providers, tried in order by the chain.

1. ``page``: SaveStream's own reader of TikTok's public video page. The only
   provider that reports the creator's download setting.
2. ``ytdlp``: yt-dlp (pinned), an independent extractor used as a second
   source for the same file.

gallery-dl was considered and left out: it is GPL-2.0 licensed. No provider
drives a browser or uses a logged-in TikTok session.
"""

from __future__ import annotations

from collections.abc import Callable

from .base import MediaSource, Provider, ProviderError, VideoInfo, VideoUnavailable
from .page import PageProvider
from .ytdlp import YtDlpProvider

__all__ = [
    "MediaSource",
    "PageProvider",
    "Provider",
    "ProviderError",
    "VideoInfo",
    "VideoUnavailable",
    "YtDlpProvider",
    "build_providers",
]

TIMEOUTS = {"page": 10.0, "ytdlp": 15.0}


def build_providers(names: tuple[str, ...], *, proxy_url: str | None) -> list[Provider]:
    known: dict[str, Callable[[], Provider]] = {
        "ytdlp": lambda: YtDlpProvider(proxy_url=proxy_url),
        "page": lambda: PageProvider(proxy_url=proxy_url),
    }
    return [known[name]() for name in names if name in known]
