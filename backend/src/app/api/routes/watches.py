from __future__ import annotations

from fastapi import APIRouter, Depends, Query, Request, status

from app.api.dependencies import (
    get_channel_verification_service,
    get_watch_service,
    require_scopes,
)
from app.api.schemas.recordings import Pagination
from app.api.schemas.watches import (
    ChannelVerificationResponse,
    CreateWatchRequest,
    UpdateWatchRequest,
    WatchListResponse,
    WatchResponse,
)
from app.api.serializers.watches import active_recording_for, watch_response
from app.application.creators.avatar_cache import remove_avatar_copy
from app.application.watches.service import WatchService
from app.application.watches.verification import (
    ChannelVerificationService,
    VerificationState,
    verification_required,
)
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1/watches", tags=["Watches"])


@router.post(
    "",
    response_model=WatchResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createWatch",
)
async def create_watch(
    payload: CreateWatchRequest,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: WatchService = Depends(get_watch_service),
) -> WatchResponse:
    watch = await service.create(principal, payload)
    entitlement = await service.entitlement_for(principal.user_id)
    waiting_room_ids = await service.waiting_room_ids(principal.user_id)
    active_recordings = await service.active_recordings(principal.user_id)
    return watch_response(
        watch,
        entitlement=entitlement,
        waiting_for_cloud_slot=(
            watch.resolved_room_id is not None
            and watch.resolved_room_id in waiting_room_ids
        ),
        active_recording=active_recording_for(watch, active_recordings),
        settings=service.settings,
    )


@router.get(
    "",
    response_model=WatchListResponse,
    operation_id="listWatches",
)
async def list_watches(
    limit: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    principal: AuthPrincipal = Depends(require_scopes("watches:read")),
    service: WatchService = Depends(get_watch_service),
) -> WatchListResponse:
    page = await service.list(
        principal,
        limit=limit,
        cursor=cursor,
        status=status_filter,
    )
    entitlement = await service.entitlement_for(principal.user_id)
    waiting_room_ids = await service.waiting_room_ids(principal.user_id)
    active_recordings = await service.active_recordings(principal.user_id)
    return WatchListResponse(
        items=[
            watch_response(
                item,
                entitlement=entitlement,
                waiting_for_cloud_slot=(
                    item.resolved_room_id is not None
                    and item.resolved_room_id in waiting_room_ids
                ),
                active_recording=active_recording_for(item, active_recordings),
                settings=service.settings,
            )
            for item in page.items
        ],
        pagination=Pagination(next_cursor=page.next_cursor, has_more=page.has_more),
    )


@router.get(
    "/{watch_id}",
    response_model=WatchResponse,
    operation_id="getWatch",
)
async def get_watch(
    watch_id: str,
    principal: AuthPrincipal = Depends(require_scopes("watches:read")),
    service: WatchService = Depends(get_watch_service),
) -> WatchResponse:
    watch = await service.get(principal, watch_id)
    entitlement = await service.entitlement_for(principal.user_id)
    waiting_room_ids = await service.waiting_room_ids(principal.user_id)
    active_recordings = await service.active_recordings(principal.user_id)
    return watch_response(
        watch,
        entitlement=entitlement,
        waiting_for_cloud_slot=(
            watch.resolved_room_id is not None
            and watch.resolved_room_id in waiting_room_ids
        ),
        active_recording=active_recording_for(watch, active_recordings),
        settings=service.settings,
    )


@router.patch(
    "/{watch_id}",
    response_model=WatchResponse,
    operation_id="updateWatch",
)
async def update_watch(
    watch_id: str,
    payload: UpdateWatchRequest,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: WatchService = Depends(get_watch_service),
) -> WatchResponse:
    watch = await service.update(principal, watch_id, payload)
    entitlement = await service.entitlement_for(principal.user_id)
    waiting_room_ids = await service.waiting_room_ids(principal.user_id)
    active_recordings = await service.active_recordings(principal.user_id)
    return watch_response(
        watch,
        entitlement=entitlement,
        waiting_for_cloud_slot=(
            watch.resolved_room_id is not None
            and watch.resolved_room_id in waiting_room_ids
        ),
        active_recording=active_recording_for(watch, active_recordings),
        settings=service.settings,
    )


@router.delete(
    "/{watch_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="deleteWatch",
)
async def delete_watch(
    watch_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: WatchService = Depends(get_watch_service),
) -> None:
    watch = await service.delete(principal, watch_id)
    # Drop the channel's avatar copy now; the periodic avatar task retries
    # if storage is unavailable (and covers other deletion paths).
    if await remove_avatar_copy(request.app.state.minio, watch):
        await service.session.commit()


@router.post(
    "/{watch_id}/resume",
    response_model=WatchResponse,
    operation_id="resumeWatch",
)
async def resume_watch(
    watch_id: str,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: WatchService = Depends(get_watch_service),
) -> WatchResponse:
    watch = await service.resume(principal, watch_id)
    entitlement = await service.entitlement_for(principal.user_id)
    waiting_room_ids = await service.waiting_room_ids(principal.user_id)
    active_recordings = await service.active_recordings(principal.user_id)
    return watch_response(
        watch,
        entitlement=entitlement,
        waiting_for_cloud_slot=(
            watch.resolved_room_id is not None
            and watch.resolved_room_id in waiting_room_ids
        ),
        active_recording=active_recording_for(watch, active_recordings),
        settings=service.settings,
    )


def _verification_response(
    state: VerificationState, service: ChannelVerificationService
) -> ChannelVerificationResponse:
    watch = state.watch
    return ChannelVerificationResponse(
        watch_id=str(watch.id),
        verified=watch.owner_verified_at is not None,
        owner_verified_at=watch.owner_verified_at,
        verification_due_at=watch.verification_due_at,
        verification_required=verification_required(watch, service.settings),
        code=state.code,
        expires_at=state.expires_at,
        checks_left=state.checks_left,
        result=state.result,
        retry_after_seconds=state.retry_after_seconds,
    )


@router.get(
    "/{watch_id}/verification",
    response_model=ChannelVerificationResponse,
    operation_id="getChannelVerification",
)
async def get_channel_verification(
    watch_id: str,
    principal: AuthPrincipal = Depends(require_scopes("watches:read")),
    service: ChannelVerificationService = Depends(get_channel_verification_service),
) -> ChannelVerificationResponse:
    return _verification_response(await service.state(principal, watch_id), service)


@router.post(
    "/{watch_id}/verification",
    response_model=ChannelVerificationResponse,
    operation_id="startChannelVerification",
)
async def start_channel_verification(
    watch_id: str,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: ChannelVerificationService = Depends(get_channel_verification_service),
) -> ChannelVerificationResponse:
    """Get the bio code for this channel (the current one while it is valid)."""
    return _verification_response(await service.start(principal, watch_id), service)


@router.post(
    "/{watch_id}/verification/check",
    response_model=ChannelVerificationResponse,
    operation_id="checkChannelVerification",
)
async def check_channel_verification(
    watch_id: str,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: ChannelVerificationService = Depends(get_channel_verification_service),
) -> ChannelVerificationResponse:
    """Look for the code in the channel's TikTok bio."""
    return _verification_response(await service.check(principal, watch_id), service)
