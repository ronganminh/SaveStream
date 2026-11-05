from __future__ import annotations

import re
from typing import Any
from uuid import UUID

from celery.result import AsyncResult
from fastapi import APIRouter, Depends, Request, status

from app.api.middleware import client_ip
from app.api.schemas.video_downloads import (
    CreateVideoDownloadRequest,
    CreateVideoDownloadResponse,
    VideoDownloadStatusResponse,
)
from app.application.video_downloads.urls import InvalidTikTokUrl, normalize_tiktok_url
from app.domain.common.errors import ApplicationError
from app.infrastructure.queue.celery_app import celery_app
from app.infrastructure.queue.tasks import video_download_run

router = APIRouter(prefix="/v1/public/video-downloads", tags=["Video Downloads"])
_JOB_ID = re.compile(r"^[0-9a-fA-F-]{36}$")


@router.post(
    "",
    response_model=CreateVideoDownloadResponse,
    status_code=status.HTTP_202_ACCEPTED,
    operation_id="createVideoDownload",
)
async def create_video_download(
    payload: CreateVideoDownloadRequest,
    request: Request,
) -> CreateVideoDownloadResponse:
    settings = request.app.state.settings
    source_ip = client_ip(request, settings.trusted_proxy_cidrs)
    await request.app.state.rate_limiter.hit(
        scope="video-download-create",
        identifier=source_ip,
        limit=8,
        window_seconds=60,
    )
    try:
        canonical_url = await __import__("asyncio").to_thread(
            normalize_tiktok_url, payload.url
        )
    except InvalidTikTokUrl as exc:
        raise ApplicationError(
            "INVALID_VIDEO_URL",
            str(exc),
            status_code=422,
            retryable=False,
        ) from exc

    task = video_download_run.apply_async(
        args=[canonical_url, payload.format],
        queue="downloads",
    )
    return CreateVideoDownloadResponse(job_id=task.id, status="queued")


@router.get(
    "/{job_id}",
    response_model=VideoDownloadStatusResponse,
    operation_id="getVideoDownload",
)
async def get_video_download(job_id: str) -> VideoDownloadStatusResponse:
    if not _JOB_ID.fullmatch(job_id):
        raise ApplicationError("RESOURCE_NOT_FOUND", "Download job not found", status_code=404)
    result: AsyncResult = celery_app.AsyncResult(str(UUID(job_id)))
    if result.state in {"PENDING", "RECEIVED", "RETRY"}:
        return VideoDownloadStatusResponse(job_id=job_id, status="queued")
    if result.state in {"STARTED", "PROGRESS"}:
        return VideoDownloadStatusResponse(job_id=job_id, status="processing")
    if result.state == "SUCCESS" and isinstance(result.result, dict):
        data: dict[str, Any] = result.result
        return VideoDownloadStatusResponse(
            job_id=job_id,
            status="completed",
            title=str(data.get("title") or "TikTok video")[:300],
            format=data.get("format") if data.get("format") in {"mp4", "mp3"} else None,
            provider=str(data.get("provider"))[:40] if data.get("provider") else None,
            download_url=data.get("download_url"),
            expires_in_seconds=int(data.get("expires_in_seconds", 0)),
        )
    if result.state == "FAILURE":
        return VideoDownloadStatusResponse(
            job_id=job_id,
            status="failed",
            error="The video could not be downloaded. It may be unavailable or unsupported.",
        )
    return VideoDownloadStatusResponse(job_id=job_id, status="processing")
