from __future__ import annotations

from fastapi import APIRouter, Depends, Query, status

from app.api.dependencies import get_watch_service, require_scopes
from app.api.schemas.recordings import Pagination
from app.api.schemas.watches import (
    CreateWatchRequest,
    UpdateWatchRequest,
    WatchListResponse,
    WatchResponse,
)
from app.api.serializers.watches import watch_response
from app.application.watches.service import WatchService
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
    return watch_response(await service.create(principal, payload))


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
        items=[watch_response(item) for item in page.items],
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
    return watch_response(await service.get(principal, watch_id))


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
    return watch_response(await service.update(principal, watch_id, payload))


@router.delete(
    "/{watch_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="deleteWatch",
)
async def delete_watch(
    watch_id: str,
    principal: AuthPrincipal = Depends(require_scopes("watches:write")),
    service: WatchService = Depends(get_watch_service),
) -> None:
    await service.delete(principal, watch_id)


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
    return watch_response(await service.resume(principal, watch_id))
