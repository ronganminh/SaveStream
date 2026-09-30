from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Protocol
from urllib.parse import quote, urlparse

import ffmpeg
import requests

from adapters.tiktok_gateway import TikTokLiveGateway
from app.api.schemas.recordings import Source
from app.settings import AppSettings
from core.tiktok_api import TikTokAPI
from engine.ports import LiveStreamGateway


@dataclass(frozen=True, slots=True)
class ResolvedSource:
    username: str
    room_id: str


class SourceResolver(Protocol):
    def resolve(self, source: Source) -> ResolvedSource: ...

    def live_status(self, source: Source) -> tuple[ResolvedSource, bool]: ...


class TikTokSourceResolver:
    def __init__(self, api: TikTokAPI) -> None:
        self.api = api

    def resolve(self, source: Source) -> ResolvedSource:
        if source.type == "username":
            username = source.value.lstrip("@").strip()
            room_id = self.api.get_room_id_from_user(username)
            return ResolvedSource(username=username, room_id=room_id)
        if source.type == "room_id":
            room_id = source.value.strip()
            username = self.api.get_user_from_room_id(room_id)
            return ResolvedSource(username=username, room_id=room_id)
        username, room_id = self.api.get_room_and_user_from_url(source.value.strip())
        return ResolvedSource(username=username, room_id=room_id)

    def live_status(self, source: Source) -> tuple[ResolvedSource, bool]:
        resolved = self.resolve(source)
        return resolved, self.api.is_room_alive(resolved.room_id)


class FakeHttpSourceResolver:
    """Resolver for the controlled Phase 10 E2E stream service.

    It is selected only through explicit non-production settings.
    """

    def __init__(self, base_url: str, *, timeout_seconds: float) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    def resolve(self, source: Source) -> ResolvedSource:
        if source.type == "room_id":
            room_id = source.value.strip()
            return ResolvedSource(username=f"e2e_{room_id}", room_id=room_id)
        if source.type == "username":
            username = source.value.lstrip("@").strip()
            return ResolvedSource(username=username, room_id=f"room-{username}")
        parsed = urlparse(source.value.strip())
        room_id = parsed.path.rstrip("/").split("/")[-1] or "e2e-room"
        return ResolvedSource(username=f"e2e_{room_id}", room_id=room_id)

    def live_status(self, source: Source) -> tuple[ResolvedSource, bool]:
        resolved = self.resolve(source)
        response = requests.get(
            f"{self.base_url}/alive/{quote(resolved.room_id, safe='')}",
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()
        payload = response.json()
        return resolved, bool(payload.get("alive"))


class HttpFakeLiveGateway:
    def __init__(self, base_url: str, *, timeout_seconds: float) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    def get_live_url(self, room_id: str) -> str | None:
        if not self.is_room_alive(room_id):
            return None
        return f"{self.base_url}/stream.flv?room_id={quote(room_id, safe='')}"

    def is_room_alive(self, room_id: str) -> bool:
        response = requests.get(
            f"{self.base_url}/alive/{quote(room_id, safe='')}",
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()
        return bool(response.json().get("alive"))

    def download_live_stream(self, live_url: str) -> Iterable[bytes]:
        with requests.get(
            live_url,
            stream=True,
            timeout=(self.timeout_seconds, max(self.timeout_seconds, 30.0)),
        ) as response:
            response.raise_for_status()
            for chunk in response.iter_content(chunk_size=4096):
                if chunk:
                    yield chunk


@dataclass(frozen=True, slots=True)
class RecordingRuntime:
    resolver: SourceResolver
    gateway: LiveStreamGateway


def build_recording_runtime(settings: AppSettings) -> RecordingRuntime:
    if settings.recording_source_backend == "fake_http":
        if settings.environment == "production":
            raise RuntimeError("fake_http recording backend is disabled in production")
        resolver = FakeHttpSourceResolver(
            settings.e2e_stream_base_url,
            timeout_seconds=settings.dependency_timeout_seconds,
        )
        gateway = HttpFakeLiveGateway(
            settings.e2e_stream_base_url,
            timeout_seconds=settings.dependency_timeout_seconds,
        )
        return RecordingRuntime(resolver=resolver, gateway=gateway)

    api = TikTokAPI(proxy=None, cookies={})
    return RecordingRuntime(
        resolver=TikTokSourceResolver(api),
        gateway=TikTokLiveGateway(api),
    )


class AtomicFFmpegMediaProcessor:
    """Validate remux output before deleting the source file."""

    def finalize(self, source_path: Path) -> Path:
        final_path = Path(str(source_path).replace("_flv.mp4", ".mp4"))
        temp_path = final_path.with_suffix(final_path.suffix + ".part")
        try:
            (
                ffmpeg.input(str(source_path))
                .output(str(temp_path), c="copy", format="mp4")
                .overwrite_output()
                .run(quiet=True)
            )
            if not temp_path.exists() or temp_path.stat().st_size <= 0:
                raise RuntimeError("FFmpeg did not produce a valid artifact")
            os.replace(temp_path, final_path)
            source_path.unlink(missing_ok=True)
            return final_path
        except Exception:
            temp_path.unlink(missing_ok=True)
            raise
