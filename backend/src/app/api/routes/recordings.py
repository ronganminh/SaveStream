from __future__ import annotations

import asyncio
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, Query, Request, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select

from app.api.dependencies import get_recording_service, require_scopes
from app.api.schemas.recordings import (
    CreateRecordingRequest,
    LiveStatusRequest,
    LiveStatusResponse,
    Pagination,
    RecordingEventResponse,
    RecordingListResponse,
    RecordingProgressData,
    RecordingResponse,
)
from app.api.serializers.recordings import recording_response
from app.application.recordings.service import RecordingService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.domain.recordings.state import RecordingStatus, TERMINAL_RECORDING_STATUSES
from app.infrastructure.db.recording_models import Recording, RecordingEvent
from app.infrastructure.recording.runtime import build_recording_runtime

router = APIRouter(prefix="/v1", tags=["Recordings"])


@router.post(
    "/live-status",
    response_model=LiveStatusResponse,
    operation_id="getLiveStatus",
)
async def live_status(
    payload: LiveStatusRequest,
    request: Request,
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
) -> LiveStatusResponse:
    del principal
    runtime = build_recording_runtime(request.app.state.settings)
    try:
        resolved, is_live = await asyncio.to_thread(
            runtime.resolver.live_status,
            payload.source,
        )
    except Exception as exc:
        raise ApplicationError(
            "STREAM_UNAVAILABLE",
            "Unable to resolve live status",
            status_code=503,
            retryable=True,
        ) from exc
    from app.api.schemas.recordings import Creator

    return LiveStatusResponse(
        source=payload.source,
        creator=Creator(
            username=resolved.username,
            display_name=resolved.username,
            avatar_url=None,
        ),
        live_status="live" if is_live else "offline",
        room_id=resolved.room_id,
        checked_at=datetime.now(timezone.utc),
    )


@router.post(
    "/recordings",
    response_model=RecordingResponse,
    status_code=status.HTTP_202_ACCEPTED,
    operation_id="createRecording",
)
async def create_recording(
    payload: CreateRecordingRequest,
    idempotency_key: str = Header(alias="Idempotency-Key"),
    principal: AuthPrincipal = Depends(require_scopes("recordings:write")),
    service: RecordingService = Depends(get_recording_service),
) -> RecordingResponse:
    recording = await service.create(
        principal,
        payload,
        idempotency_key=idempotency_key,
    )
    return recording_response(recording)


@router.get(
    "/recordings",
    response_model=RecordingListResponse,
    operation_id="listRecordings",
)
async def list_recordings(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
    service: RecordingService = Depends(get_recording_service),
) -> RecordingListResponse:
    page = await service.list(
        principal,
        limit=limit,
        cursor=cursor,
        status=status_filter,
    )
    days = await service.retention_days_for(principal.user_id)
    positions = await service.queue_positions(page.items)
    return RecordingListResponse(
        items=[
            recording_response(
                item,
                retention_days=days,
                queue_position=positions.get(item.id),
            )
            for item in page.items
        ],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
    )


@router.get(
    "/recordings/{recording_id}",
    response_model=RecordingResponse,
    operation_id="getRecording",
)
async def get_recording(
    recording_id: str,
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
    service: RecordingService = Depends(get_recording_service),
) -> RecordingResponse:
    recording = await service.get(principal, recording_id)
    days = await service.retention_days_for(principal.user_id)
    queue_position = await service.queue_position(recording)
    return recording_response(
        recording,
        retention_days=days,
        queue_position=queue_position,
    )


@router.post(
    "/recordings/{recording_id}/stop",
    response_model=RecordingResponse,
    status_code=status.HTTP_202_ACCEPTED,
    operation_id="stopRecording",
)
async def stop_recording(
    recording_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(require_scopes("recordings:write")),
    service: RecordingService = Depends(get_recording_service),
) -> RecordingResponse:
    recording = await service.stop(principal, recording_id)
    try:
        await request.app.state.redis.client.set(
            f"savestream:recording:stop:{recording.id}",
            "1",
            ex=86400,
        )
    except Exception:
        pass
    return recording_response(recording)


@router.delete(
    "/recordings/{recording_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="deleteRecording",
)
async def delete_recording(
    recording_id: str,
    principal: AuthPrincipal = Depends(require_scopes("recordings:write")),
    service: RecordingService = Depends(get_recording_service),
) -> None:
    await service.soft_delete(principal, recording_id)


async def _last_sequence(database, recording_id: uuid.UUID, last_event_id: str | None) -> int:
    if not last_event_id:
        return 0
    try:
        event_id = uuid.UUID(last_event_id)
    except ValueError as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid Last-Event-ID", status_code=400
        ) from exc
    async with database.session() as session:
        event = await session.scalar(
            select(RecordingEvent).where(
                RecordingEvent.id == event_id,
                RecordingEvent.recording_id == recording_id,
            )
        )
        if event is None:
            return 0
        return event.sequence


@router.get(
    "/recordings/{recording_id}/events",
    response_class=StreamingResponse,
    operation_id="streamRecordingEvents",
)
async def stream_recording_events(
    recording_id: str,
    request: Request,
    last_event_id: str | None = Header(default=None, alias="Last-Event-ID"),
    principal: AuthPrincipal = Depends(require_scopes("recordings:read")),
    service: RecordingService = Depends(get_recording_service),
):
    recording = await service.get(principal, recording_id)
    database = request.app.state.database
    poll_seconds = request.app.state.settings.sse_poll_seconds
    sequence = await _last_sequence(database, recording.id, last_event_id)

    async def event_stream():
        nonlocal sequence
        idle_ticks = 0
        while True:
            if await request.is_disconnected():
                return
            async with database.session() as session:
                events = list(
                    (
                        await session.scalars(
                            select(RecordingEvent)
                            .where(
                                RecordingEvent.recording_id == recording.id,
                                RecordingEvent.sequence > sequence,
                            )
                            .order_by(RecordingEvent.sequence)
                            .limit(100)
                        )
                    ).all()
                )
                current = await session.get(Recording, recording.id)
            if events:
                idle_ticks = 0
                for event in events:
                    sequence = event.sequence
                    data = RecordingEventResponse(
                        id=str(event.id),
                        sequence=event.sequence,
                        type=event.event_type,
                        recording_id=str(event.recording_id),
                        created_at=event.created_at,
                        data=RecordingProgressData(**event.data),
                    ).model_dump_json()
                    yield f"id: {event.id}\nevent: {event.event_type}\ndata: {data}\n\n"
            else:
                idle_ticks += 1
                if idle_ticks % 15 == 0:
                    yield ": keep-alive\n\n"
            if (
                current is None
                or RecordingStatus(current.status) in TERMINAL_RECORDING_STATUSES
            ) and not events:
                return
            await asyncio.sleep(poll_seconds)

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
