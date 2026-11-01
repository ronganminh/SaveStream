from __future__ import annotations

import asyncio
import logging
import tempfile
from pathlib import Path
from typing import Any, Callable
from urllib.parse import quote, urlsplit

import requests
import yt_dlp

from app.application.video_downloads.urls import normalize_tiktok_url
from app.infrastructure.storage.minio import MinioStorageClient
from app.settings import get_app_settings

logger = logging.getLogger("savestream.video_downloads")
_MAX_FILE_BYTES = 512 * 1024 * 1024
_MEDIA_HOST_SUFFIXES = (
    ".tiktokcdn.com",
    ".tiktokv.com",
    ".byteoversea.com",
    ".ibytedtos.com",
    ".muscdn.com",
    ".tiktok.com",
)


def _validate_media_url(value: str) -> str:
    parts = urlsplit(value)
    host = (parts.hostname or "").lower().rstrip(".")
    if (
        parts.scheme != "https"
        or not host
        or parts.username
        or parts.password
        or parts.port not in {None, 443}
        or not any(host.endswith(suffix) for suffix in _MEDIA_HOST_SUFFIXES)
    ):
        raise RuntimeError("Provider returned an unsupported media URL")
    return value


def _stream_media_url(value: str, destination: Path) -> None:
    current = _validate_media_url(value)
    with requests.Session() as session:
        for _ in range(4):
            response = session.get(
                current,
                stream=True,
                allow_redirects=False,
                timeout=(10, 30),
                headers={
                    "User-Agent": "SaveStream/1.0",
                    "Referer": "https://www.tiktok.com/",
                    "Accept-Encoding": "identity",
                },
            )
            try:
                if response.is_redirect or response.is_permanent_redirect:
                    location = response.headers.get("Location")
                    if not location:
                        raise RuntimeError("Media provider returned an invalid redirect")
                    from urllib.parse import urljoin

                    current = _validate_media_url(urljoin(current, location))
                    continue
                response.raise_for_status()
                declared_size = response.headers.get("Content-Length")
                if declared_size and int(declared_size) > _MAX_FILE_BYTES:
                    raise RuntimeError("Downloaded file exceeds the allowed size")
                total = 0
                with destination.open("wb") as output:
                    for chunk in response.iter_content(chunk_size=1024 * 256):
                        if not chunk:
                            continue
                        total += len(chunk)
                        if total > _MAX_FILE_BYTES:
                            raise RuntimeError("Downloaded file exceeds the allowed size")
                        output.write(chunk)
                if total <= 0:
                    raise RuntimeError("Provider returned an empty media file")
                return
            finally:
                response.close()
    raise RuntimeError("Too many media redirects")


def _download_with_ytdlp(url: str, output_dir: Path) -> str:
    options: dict[str, Any] = {
        "outtmpl": str(output_dir / "source.%(ext)s"),
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
        "format": "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
        "merge_output_format": "mp4",
    }
    with yt_dlp.YoutubeDL(options) as downloader:
        info = downloader.extract_info(url, download=True)
        if not info:
            raise RuntimeError("yt-dlp returned no video information")
        title = str(info.get("title") or "TikTok video")[:300]
    candidates = [p for p in output_dir.iterdir() if p.is_file() and p.suffix.lower() == ".mp4"]
    if not candidates:
        raise RuntimeError("yt-dlp did not produce an MP4 file")
    return title


def _download_with_tiktokdl(url: str, output_dir: Path) -> str:
    from tiktokdl.download_post import get_post

    post = asyncio.run(
        get_post(
            url,
            download=False,
            browser="chromium",
            headless=True,
            request_timeout=15000,
            retries=1,
        )
    )
    media_url = _validate_media_url(str(getattr(post, "download_url", "")))
    _stream_media_url(media_url, output_dir / "tiktokdl.mp4")
    return str(getattr(post, "post_description", None) or "TikTok video")[:300]


def _download_with_tiktokapi(url: str, output_dir: Path) -> str:
    from TikTokApi import TikTokApi

    async def extract_and_download() -> str:
        async with TikTokApi() as api:
            await api.create_sessions(num_sessions=1, sleep_after=3, browser="chromium")
            video = api.video(url=url)
            data = await video.info()
            video_data = data.get("video") or {}
            media_url = video_data.get("downloadAddr") or video_data.get("playAddr")
            if not media_url:
                raise RuntimeError("TikTokApi returned no downloadable media URL")
            _stream_media_url(str(media_url), output_dir / "tiktokapi.mp4")
            desc = str(data.get("desc") or "TikTok video")
            return desc[:300]

    return asyncio.run(extract_and_download())


def _validate_output(output_dir: Path) -> Path:
    candidates = [
        path for path in output_dir.iterdir()
        if path.is_file() and path.suffix.lower() == ".mp4"
    ]
    if not candidates:
        raise RuntimeError("Provider did not produce an MP4 file")
    source = max(candidates, key=lambda path: path.stat().st_size)
    size = source.stat().st_size
    if size <= 0 or size > _MAX_FILE_BYTES:
        raise RuntimeError("Downloaded file exceeds the allowed size")
    with source.open("rb") as media:
        header = media.read(16)
    if len(header) < 8 or header[4:8] != b"ftyp":
        raise RuntimeError("Downloaded file is not a valid MP4 container")
    return source


def run_video_download(job_id: str, url: str, output_format: str) -> dict[str, Any]:
    """Try independent public-video providers in order; never use account cookies."""
    if output_format not in {"mp4", "mp3"}:
        raise ValueError("Unsupported output format")
    canonical_url = normalize_tiktok_url(url)
    settings = get_app_settings()
    storage = MinioStorageClient(settings)

    providers: tuple[tuple[str, Callable[[str, Path], str]], ...] = (
        ("yt-dlp", _download_with_ytdlp),
        ("tiktok-dlpy", _download_with_tiktokdl),
        ("TikTokApi", _download_with_tiktokapi),
    )
    errors: list[str] = []
    title = "TikTok video"

    with tempfile.TemporaryDirectory(prefix="savestream-download-") as temp_dir:
        output_dir = Path(temp_dir)
        source: Path | None = None
        provider_used: str | None = None
        for provider_name, provider in providers:
            for stale_file in output_dir.iterdir():
                if stale_file.is_file():
                    stale_file.unlink()
            try:
                title = provider(canonical_url, output_dir)
                source = _validate_output(output_dir)
                provider_used = provider_name
                break
            except Exception as exc:
                errors.append(f"{provider_name}: {type(exc).__name__}")
                logger.warning(
                    "video provider failed job_id=%s provider=%s error_type=%s",
                    job_id,
                    provider_name,
                    type(exc).__name__,
                )

        if source is None or provider_used is None:
            raise RuntimeError("All TikTok download providers failed: " + "; ".join(errors))

        extension = "mp4"
        if output_format == "mp3":
            import subprocess

            audio_path = output_dir / "audio.mp3"
            completed = subprocess.run(
                [
                    "ffmpeg", "-nostdin", "-y", "-i", str(source),
                    "-vn", "-codec:a", "libmp3lame", "-b:a", "192k", str(audio_path),
                ],
                capture_output=True,
                check=False,
                timeout=120,
            )
            if completed.returncode != 0 or not audio_path.is_file():
                raise RuntimeError("Could not convert the downloaded video to MP3")
            source = audio_path
            extension = "mp3"

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
            "video download completed job_id=%s provider=%s format=%s size_bytes=%s",
            job_id,
            provider_used,
            extension,
            size,
        )
        return {
            "title": title,
            "format": extension,
            "provider": provider_used,
            "download_url": download_url,
            "expires_in_seconds": settings.artifact_presign_seconds,
            "size_bytes": size,
        }
