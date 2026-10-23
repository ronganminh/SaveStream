from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

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
from app.application.watches.channel_stats import watch_extras
from app.application.creators.avatar_cache import CreatorAvatarCache, remove_avatar_copy
from app.application.watches.service import WatchService
from app.application.watches.verification import (
    ChannelVerificationService,
    VerificationState,
    verification_required,
)
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.creators.avatar_fetch import download_avatar
from app.infrastructure.db.watch_models import Watch

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1/watches", tags=["Watches"])


async def _watch_responses(
    service: WatchService,
    principal: AuthPrincipal,
    watches: list[Watch],
) -> list[WatchResponse]:
    """Serialize Watches with a fixed number of queries, however many there are."""
    entitlement = await service.entitlement_for(principal.user_id)
    waiting_room_ids = await service.waiting_room_ids(principal.user_id)
    active_recordings = await service.active_recordings(principal.user_id)
    extras = await watch_extras(
        service.session,
        service.settings,
        user_id=principal.user_id,
        watches=watches,
    )
    return [
        watch_response(
            watch,
            entitlement=entitlement,
            waiting_for_cloud_slot=(
                watch.resolved_room_id is not None
                and watch.resolved_room_id in waiting_room_ids
            ),
            active_recording=active_recording_for(watch, active_recordings),
            settings=service.settings,
            extras=extras.get(watch.id),
        )
        for watch in watches
    ]


@router.post(
    "",
    response_model=WatchResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createWatch",
)
async def create_watch(
    payload: CreateWatchRequest,
    request: Request,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: WatchService = Depends(get_watch_service),
) -> WatchResponse:
    watch = await service.create(principal, payload)
    await _copy_avatar_now(request, service, watch)
    return (await _watch_responses(service, principal, [watch]))[0]


async def _copy_avatar_now(request: Request, service: WatchService, watch: Watch) -> None:
    """Copy a new channel's avatar right away so it shows at once (the
    periodic task keeps it fresh). Best-effort and time-boxed."""
    if not watch.creator_avatar_url or watch.creator_avatar_key:
        return
    cache = CreatorAvatarCache(
        service.session, service.settings, request.app.state.minio, download_avatar
    )
    try:
        await asyncio.wait_for(
            cache.refresh_watch(watch, now=datetime.now(timezone.utc)), timeout=6.0
        )
    except Exception:
        # refresh_watch records its own failures (retried within the hour);
        # only a timeout lands here, and the periodic task catches up.
        logger.info("Creator avatar copy on create failed", exc_info=True)
    await service.session.commit()


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
    return WatchListResponse(
        items=await _watch_responses(service, principal, page.items),
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
    return (await _watch_responses(service, principal, [watch]))[0]


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
    return (await _watch_responses(service, principal, [watch]))[0]


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
    return (await _watch_responses(service, principal, [watch]))[0]


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
