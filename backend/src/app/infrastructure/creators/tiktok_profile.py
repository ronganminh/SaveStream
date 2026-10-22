from __future__ import annotations

import asyncio
import re
from urllib.parse import urlparse

from app.api.schemas.recordings import Source
from app.application.watches.service import CreatorMetadata
from app.application.watches.verification import ChannelProfile
from core.tiktok_api import TikTokAPI


class TikTokCreatorMetadataLookup:
    """Best-effort TikTok profile lookup used only when a Watch is created."""

    async def lookup(self, source: Source) -> CreatorMetadata | None:
        username = _username_from_source(source)
        if username is None:
            return None
        profile = await asyncio.to_thread(_get_profile, username)
        if profile is None:
            return None
        return CreatorMetadata(
            username=profile.username,
            display_name=profile.display_name,
            avatar_url=profile.avatar_url,
        )


class TikTokChannelProfileLookup:
    """Reads a channel's public bio for ownership verification."""

    async def fetch(self, username: str) -> ChannelProfile | None:
        profile = await asyncio.to_thread(_get_profile, username)
        if profile is None:
            return None
        return ChannelProfile(
            username=profile.username,
            bio=profile.signature,
            tiktok_user_id=profile.user_id,
        )


def _get_profile(username: str):
    return TikTokAPI(proxy=None, cookies={}).get_user_profile(username)


def _username_from_source(source: Source) -> str | None:
    if source.type == "username":
        value = source.value.lstrip("@").strip()
        return value or None
    if source.type != "url":
        return None
    parsed = urlparse(source.value)
    if parsed.scheme not in {"http", "https"}:
        return None
    match = re.match(r"^/@([A-Za-z0-9._]{2,24})(?:/|$)", parsed.path)
    return match.group(1) if match else None
