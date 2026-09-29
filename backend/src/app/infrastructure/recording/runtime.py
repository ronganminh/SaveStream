from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import ffmpeg

from app.api.schemas.recordings import Source
from core.tiktok_api import TikTokAPI


@dataclass(frozen=True, slots=True)
class ResolvedSource:
    username: str
    room_id: str


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


class AtomicFFmpegMediaProcessor:
    """Worker-safe remuxer that validates output before deleting the source."""

    def finalize(self, source_path: Path) -> Path:
        final_path = Path(str(source_path).replace("_flv.mp4", ".mp4"))
        temp_path = final_path.with_suffix(final_path.suffix + ".part")
        try:
            (
                ffmpeg.input(str(source_path))
                .output(str(temp_path), c="copy")
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
