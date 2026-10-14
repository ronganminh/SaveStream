from __future__ import annotations

import asyncio
import functools
from datetime import datetime, timedelta, timezone

from typing import Literal

from fastapi import APIRouter, Depends, Query, Request

from app.api.dependencies import get_recording_service, require_scopes
from app.api.schemas.recordings import (
    ArtifactsResponse,
    DownloadUrlResponse,
)
from app.api.serializers.recordings import artifact_response
from app.application.recordings.download import attachment_disposition, download_filename
from app.application.recordings.service import RecordingService
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.recording_models import Recording

router = APIRouter(prefix="/v1", tags=["Recordings"])


@router.get(
    "/recordings/{recording_id}/artifacts",
    response_model=ArtifactsResponse,
    operation_id="listRecordingArtifacts",
)
async def list_artifacts(
    recording_id: str,
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
    service: RecordingService = Depends(get_recording_service),
) -> ArtifactsResponse:
    artifacts = await service.artifacts(principal, recording_id)
    return ArtifactsResponse(items=[artifact_response(item) for item in artifacts])


@router.post(
    "/artifacts/{artifact_id}/download-url",
    response_model=DownloadUrlResponse,
    operation_id="createArtifactDownloadUrl",
)
async def create_download_url(
    artifact_id: str,
    request: Request,
    disposition: Literal["inline", "attachment"] = Query(
        default="inline",
        description=(
            "`attachment` signs a Content-Disposition so the browser saves the "
            "file under a readable name instead of playing it."
        ),
    ),
    tz_offset_minutes: int = Query(
        default=0,
        ge=-14 * 60,
        le=14 * 60,
        description="Viewer's UTC offset, used for the time in the file name.",
    ),
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
    service: RecordingService = Depends(get_recording_service),
) -> DownloadUrlResponse:
    artifact = await service.artifact(principal, artifact_id)
    content_disposition = None
    if disposition == "attachment":
        recording = await service.session.get(Recording, artifact.recording_id)
        if recording is not None:
            content_disposition = attachment_disposition(
                download_filename(recording, tz_offset_minutes=tz_offset_minutes)
            )
    url = await asyncio.to_thread(
        functools.partial(
            request.app.state.minio.presigned_get_url,
            artifact.storage_key,
            content_disposition=content_disposition,
        )
    )
    return DownloadUrlResponse(
        url=url,
        expires_at=datetime.now(timezone.utc)
        + timedelta(seconds=request.app.state.settings.artifact_presign_seconds),
    )
