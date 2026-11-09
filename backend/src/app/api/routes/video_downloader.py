"""Video downloader endpoints served by the API (the downloads themselves
are served by the separate downloader container)."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_db_session
from app.api.middleware import client_ip as trusted_client_ip
from app.api.schemas.video_downloader import (
    VideoDownloadReportRequest,
    VideoDownloadReportResponse,
)
from app.application.public_reports import verify_turnstile
from app.application.video_downloader.blocklist import (
    BlocklistService,
    guard_report,
    new_reference,
    push_change,
)
from app.downloader.state import BLOCKLIST_SYNCED_KEY

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/v1/public", tags=["Video downloader"])


@router.post(
    "/video-downloader-reports",
    response_model=VideoDownloadReportResponse,
    status_code=201,
    operation_id="createVideoDownloadReport",
)
async def create_video_download_report(
    payload: VideoDownloadReportRequest,
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> VideoDownloadReportResponse:
    settings = request.app.state.settings
    ip = trusted_client_ip(request, settings.trusted_proxy_cidrs)
    await guard_report(
        request.app.state.rate_limiter,
        client_ip=ip,
        turnstile_secret=settings.turnstile_secret_key,
        turnstile_token=payload.turnstile_token,
        turnstile=lambda token, remote: verify_turnstile(
            settings.turnstile_secret_key, token, remote
        ),
    )
    if (payload.website or "").strip():
        return VideoDownloadReportResponse(reference=new_reference())
    report = await BlocklistService(session).submit_report(
        video_url=payload.video_url,
        reporter_name=payload.reporter_name,
        reporter_email=payload.reporter_email,
        relationship=payload.relationship,
        reason=payload.reason,
        details=payload.details,
    )
    await session.commit()
    await push_blocklist_change(request, report.video_id, blocked=True)
    return VideoDownloadReportResponse(reference=report.reference)


async def push_blocklist_change(request: Request, video_id: str, *, blocked: bool) -> None:
    """Update the downloader's Redis copy after the commit. If that fails,
    drop the "synced" marker so the downloader refuses everything until the
    periodic sync has copied the database again (fail closed)."""
    client = request.app.state.redis.client
    try:
        await push_change(client, video_id=video_id, blocked=blocked)
    except Exception:
        logger.exception("video downloader blocklist push failed video_id=%s", video_id)
        try:
            await client.delete(BLOCKLIST_SYNCED_KEY)
        except Exception:
            logger.exception("could not clear the downloader blocklist marker")
