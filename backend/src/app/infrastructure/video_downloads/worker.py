from __future__ import annotations

import logging
import tempfile
from pathlib import Path
from typing import Any
from urllib.parse import quote

import yt_dlp

from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import get_app_settings

logger = logging.getLogger("savestream.video_downloads")
_MAX_FILE_BYTES = 512 * 1024 * 1024


def run_video_download(job_id: str, url: str, output_format: str) -> dict[str, Any]:
    """Download a public, directly accessible TikTok video with no account cookies."""
    if output_format not in {"mp4", "mp3"}:
        raise ValueError("Unsupported output format")
    settings = get_app_settings()
    storage = MinioStorageClient(settings)
    with tempfile.TemporaryDirectory(prefix="savestream-download-") as temp_dir:
        output_dir = Path(temp_dir)
        options: dict[str, Any] = {
            "outtmpl": str(output_dir / "%(id)s.%(ext)s"),
            "noplaylist": True,
            "quiet": True,
            "no_warnings": True,
            "socket_timeout": 20,
            "retries": 2,
            "fragment_retries": 2,
            "extractor_retries": 1,
            "max_filesize": _MAX_FILE_BYTES,
            "cachedir": False,
            "restrictfilenames": True,
            "format": (
                "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
                if output_format == "mp4"
                else "bestaudio/best"
            ),
        }
        if output_format == "mp4":
            options["merge_output_format"] = "mp4"
        else:
            options["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ]

        with yt_dlp.YoutubeDL(options) as downloader:
            info = downloader.extract_info(url, download=True)
            if not info:
                raise RuntimeError("No downloadable video was returned")
            title = str(info.get("title") or "TikTok video")[:300]

        extension = "mp4" if output_format == "mp4" else "mp3"
        candidates = [
            path for path in output_dir.iterdir()
            if path.is_file() and path.suffix.lower() == f".{extension}"
        ]
        if not candidates:
            raise RuntimeError("The extractor did not produce the requested format")
        source = max(candidates, key=lambda path: path.stat().st_size)
        size = source.stat().st_size
        if size <= 0 or size > _MAX_FILE_BYTES:
            raise RuntimeError("Downloaded file exceeds the allowed size")
        storage_key = f"downloads/{job_id}.{extension}"
        content_type = "video/mp4" if extension == "mp4" else "audio/mpeg"
        storage.upload_file(source, storage_key, content_type=content_type)
        filename = f"savestream-{job_id}.{extension}"
        download_url = storage.presigned_get_url(
            storage_key,
            content_disposition=f'attachment; filename="{quote(filename)}"',
            content_type=content_type,
        )
        logger.info(
            "video download completed job_id=%s format=%s size_bytes=%s",
            job_id,
            extension,
            size,
        )
        return {
            "title": title,
            "format": extension,
            "download_url": download_url,
            "expires_in_seconds": settings.artifact_presign_seconds,
            "size_bytes": size,
        }
