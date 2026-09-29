from __future__ import annotations

from pathlib import Path
from typing import Callable

from utils.video_management import VideoManagement


class FFmpegMediaProcessor:
    def __init__(
        self,
        converter: Callable[[str], None] = VideoManagement.convert_flv_to_mp4,
    ) -> None:
        self._converter = converter

    def finalize(self, source_path: Path) -> Path:
        self._converter(str(source_path))
        return Path(str(source_path).replace("_flv.mp4", ".mp4"))
