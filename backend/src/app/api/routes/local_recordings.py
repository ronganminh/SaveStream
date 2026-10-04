from __future__ import annotations

from typing import cast

from fastapi import APIRouter, Depends, Header, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.local_recordings import (
    CreateLocalRecordingSessionRequest,
    ExtendLocalRecordingSessionRequest,
    FinishLocalRecordingSessionRequest,
    LocalRecordingListResponse,
    LocalRecordingResponse,
    LocalRecordingSessionStartResponse,
    LocalRecordingStatus,
    LocalRecordingStream,
)
from app.api.schemas.recordings import Creator, Pagination
from app.application.local_recordings.service import LocalRecordingService
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1", tags=["Local Recordings"])


@router.post(
    "/local-recordings/sessions",
    response_model=LocalRecordingSessionStartResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createLocalRecordingSession",
)
async def create_local_recording_session(
    payload: CreateLocalRecordingSessionRequest,
    request: Request,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> LocalRecordingSessionStartResponse:
    grant = await LocalRecordingService(
        session,
        request.app.state.settings,
    ).start(
        principal.user_id,
        payload,
        idempotency_key=idempotency_key,
    )
    return LocalRecordingSessionStartResponse(
        session_id=str(grant.session_id),
        granted_seconds=grant.granted_seconds,
        lease_expires_at=grant.lease_expires_at,
        stream=LocalRecordingStream(
            url=grant.stream_url,
            format=grant.stream_format,
            headers=grant.stream_headers,
        ),
    )


@router.post(
    "/local-recordings/sessions/{session_id}/extend",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="extendLocalRecordingSession",
)
async def extend_local_recording_session(
    payload: ExtendLocalRecordingSessionRequest,
    session_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    await LocalRecordingService(
        session,
        request.app.state.settings,
    ).extend(
        principal.user_id,
        session_id,
        reward_id=payload.reward_id,
    )


@router.post(
    "/local-recordings/sessions/{session_id}/finish",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="finishLocalRecordingSession",
)
async def finish_local_recording_session(
    payload: FinishLocalRecordingSessionRequest,
    session_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    await LocalRecordingService(
        session,
        request.app.state.settings,
    ).finish(principal.user_id, session_id, payload)


@router.get(
    "/local-recordings",
    response_model=LocalRecordingListResponse,
    operation_id="listLocalRecordings",
)
async def list_local_recordings(
    request: Request,
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> LocalRecordingListResponse:
    page = await LocalRecordingService(
        session,
        request.app.state.settings,
    ).list(
        principal.user_id,
        limit=limit,
        cursor=cursor,
    )
    return LocalRecordingListResponse(
        items=[
            LocalRecordingResponse(
                id=str(item.id),
                watch_id=str(item.watch_id),
                creator=Creator(
                    username=item.creator_username,
                    display_name=item.creator_username,
                    avatar_url=None,
                ),
                device_id=item.device_id,
                device_name=item.device_name,
                started_at=item.started_at,
                recorded_seconds=item.recorded_seconds,
                size_bytes=item.size_bytes,
                status=cast(LocalRecordingStatus, item.status),
            )
            for item in page.items
        ],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.delete(
    "/local-recordings/{id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="deleteLocalRecording",
)
async def delete_local_recording(
    id: str,
    request: Request,
    device_id: str = Query(min_length=1),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> None:
    await LocalRecordingService(
        session,
        request.app.state.settings,
    ).delete(
        principal.user_id,
        id,
        device_id=device_id,
    )
