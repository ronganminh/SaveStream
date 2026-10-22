from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass
from urllib.parse import urlparse

from app.api.schemas.recordings import Source
from app.application.watches.service import CreatorMetadata
from app.application.watches.verification import ChannelProfile
from core.tiktok_api import TikTokAPI, TikTokProfileLookup


@dataclass(frozen=True, slots=True)
class CreatorLookupResult:
    metadata: CreatorMetadata | None
    # True only when TikTok's profile page says the handle does not exist.
    # Room-id sources and unreadable pages are never reported as not found.
    not_found: bool = False


class TikTokCreatorMetadataLookup:
    """Best-effort TikTok profile lookup used only when a Watch is created."""

    async def lookup(self, source: Source) -> CreatorMetadata | None:
        return (await self.resolve(source)).metadata

    async def resolve(self, source: Source) -> CreatorLookupResult:
        username = _username_from_source(source)
        if username is None:
            return CreatorLookupResult(metadata=None)
        result = await asyncio.to_thread(_lookup_profile, username)
        profile = result.profile
        if profile is None:
            return CreatorLookupResult(metadata=None, not_found=result.not_found)
        return CreatorLookupResult(
            metadata=CreatorMetadata(
                username=profile.username,
                display_name=profile.display_name,
                avatar_url=profile.avatar_url,
            )
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


def _lookup_profile(username: str) -> TikTokProfileLookup:
    return TikTokAPI(proxy=None, cookies={}).lookup_user_profile(username)


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
