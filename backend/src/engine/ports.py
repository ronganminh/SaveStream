from __future__ import annotations

from pathlib import Path
from typing import Iterable, Protocol


class LiveStreamGateway(Protocol):
    def get_live_url(self, room_id: str) -> str | None: ...

    def is_room_alive(self, room_id: str) -> bool: ...

    def download_live_stream(self, live_url: str) -> Iterable[bytes]: ...


class MediaProcessor(Protocol):
    def finalize(self, source_path: Path) -> Path: ...
