from __future__ import annotations

from pathlib import Path
from types import SimpleNamespace

import pytest

from app.infrastructure.video_downloads import worker


def _write_valid_mp4(path: Path) -> None:
    path.write_bytes(b"\x00\x00\x00\x18ftypmp42")


def test_public_download_permission_fails_closed() -> None:
    worker._assert_public_download_enabled({"author": {"downloadSetting": 0}})
    with pytest.raises(RuntimeError, match="explicitly denies public downloads"):
        worker._assert_public_download_enabled({"author": {"downloadSetting": 3}})
    with pytest.raises(RuntimeError, match="missing author.downloadSetting"):
        worker._assert_public_download_enabled({"author": {}})



def test_find_video_metadata_supports_nested_page_state_shapes() -> None:
    page_state = {
        "__DEFAULT_SCOPE__": {
            "webapp.video-detail": {
                "itemInfo": {
                    "itemStruct": {
                        "id": "7702885119203216661",
                        "author": {"id": "creator", "downloadSetting": 0},
                        "video": {"playAddr": "https://example.invalid/video.mp4"},
                    }
                }
            }
        }
    }

    result = worker._find_video_metadata(page_state, "7702885119203216661")

    assert result is not None
    assert result["author"]["downloadSetting"] == 0


def test_find_video_metadata_does_not_infer_permission_from_missing_setting() -> None:
    page_state = {
        "ItemModule": {
            "7702885119203216661": {
                "id": "7702885119203216661",
                "author": {"id": "creator"},
            }
        }
    }

    assert worker._find_video_metadata(page_state, "7702885119203216661") is None


def test_media_url_rejects_non_tiktok_hosts() -> None:
    with pytest.raises(RuntimeError):
        worker._validate_media_url("https://127.0.0.1/private.mp4")


def test_provider_chain_falls_back_and_reports_winner(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[str] = []

    def ytdlp(url: str, output_dir: Path) -> str:
        calls.append("yt-dlp")
        raise RuntimeError("extractor unavailable")

    def tiktokdl(url: str, output_dir: Path) -> str:
        calls.append("tiktok-dlpy")
        _write_valid_mp4(output_dir / "fallback.mp4")
        return "Fallback title"

    def tiktokapi(url: str, output_dir: Path) -> str:
        calls.append("TikTokApi")
        raise AssertionError("third provider should not run")

    class Storage:
        def upload_file(self, source: Path, key: str, content_type: str) -> None:
            assert source.is_file()
            assert key.endswith(".mp4")
            assert content_type == "video/mp4"

        def presigned_get_url(self, key: str, **kwargs: object) -> str:
            return "https://storage.example/download"

    monkeypatch.setattr(worker, "normalize_tiktok_url", lambda value: value)
    monkeypatch.setattr(worker, "_verify_public_download_permission", lambda value: {})
    monkeypatch.setattr(worker, "get_app_settings", lambda: SimpleNamespace(artifact_presign_seconds=900))
    monkeypatch.setattr(worker, "MinioStorageClient", lambda settings: Storage())
    monkeypatch.setattr(worker, "_download_with_ytdlp", ytdlp)
    monkeypatch.setattr(worker, "_download_with_tiktokdl", tiktokdl)
    monkeypatch.setattr(worker, "_download_with_tiktokapi", tiktokapi)
    monkeypatch.setattr(worker, "_schedule_download_cleanup", lambda storage_key: None)

    result = worker.run_video_download("job-1", "https://www.tiktok.com/@user/video/123", "mp4")

    assert calls == ["yt-dlp", "tiktok-dlpy"]
    assert result["provider"] == "tiktok-dlpy"
    assert result["title"] == "Fallback title"
    assert result["download_url"] == "https://storage.example/download"


def test_provider_chain_raises_after_all_providers_fail(monkeypatch: pytest.MonkeyPatch) -> None:
    class Storage:
        pass

    monkeypatch.setattr(worker, "normalize_tiktok_url", lambda value: value)
    monkeypatch.setattr(worker, "_verify_public_download_permission", lambda value: {})
    monkeypatch.setattr(worker, "get_app_settings", lambda: SimpleNamespace(artifact_presign_seconds=900))
    monkeypatch.setattr(worker, "MinioStorageClient", lambda settings: Storage())

    def fail(url: str, output_dir: Path) -> str:
        raise RuntimeError("provider failed")

    monkeypatch.setattr(worker, "_download_with_ytdlp", fail)
    monkeypatch.setattr(worker, "_download_with_tiktokdl", fail)
    monkeypatch.setattr(worker, "_download_with_tiktokapi", fail)

    with pytest.raises(RuntimeError, match="All TikTok download providers failed"):
        worker.run_video_download("job-2", "https://www.tiktok.com/@user/video/123", "mp4")
