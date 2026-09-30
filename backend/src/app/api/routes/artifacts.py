from __future__ import annotations

import asyncio
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Request

from app.api.dependencies import get_recording_service, require_scopes
from app.api.schemas.recordings import (
    ArtifactsResponse,
    DownloadUrlResponse,
)
from app.api.serializers.recordings import artifact_response
from app.application.recordings.service import RecordingService
from app.domain.identity.types import AuthPrincipal

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
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
    service: RecordingService = Depends(get_recording_service),
) -> DownloadUrlResponse:
    artifact = await service.artifact(principal, artifact_id)
    url = await asyncio.to_thread(
        request.app.state.minio.presigned_get_url,
        artifact.storage_key,
    )
    return DownloadUrlResponse(
        url=url,
        expires_at=datetime.now(timezone.utc)
        + timedelta(seconds=request.app.state.settings.artifact_presign_seconds),
    )
