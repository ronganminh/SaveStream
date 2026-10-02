from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.notifications import (
    MarkAllReadResponse,
    NotificationListResponse,
    NotificationPreferenceResponse,
    NotificationResponse,
    NotificationUpdateRequest,
    UpdateNotificationPreferencesRequest,
)
from app.api.schemas.recordings import Pagination
from app.application.notifications.service import NotificationService
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import UserNotification
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/v1", tags=["Notifications"])


def _response(item: UserNotification) -> NotificationResponse:
    return NotificationResponse(
        id=str(item.id),
        type=item.kind,
        title=item.title,
        body=item.body,
        read=item.read_at is not None,
        resource_type=item.resource_type,
        resource_id=item.resource_id,
        created_at=item.created_at,
    )


@router.get(
    "/notifications",
    response_model=NotificationListResponse,
    operation_id="listNotifications",
)
async def list_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    cursor: str | None = Query(default=None),
    unread_only: bool = Query(default=False),
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> NotificationListResponse:
    page = await NotificationService(session).list(
        principal,
        limit=limit,
        cursor=cursor,
        unread_only=unread_only,
    )
    return NotificationListResponse(
        items=[_response(item) for item in page.items],
        pagination=Pagination(
            next_cursor=page.next_cursor,
            has_more=page.has_more,
        ),
    )


@router.patch(
    "/notifications/{notification_id}",
    response_model=NotificationResponse,
    operation_id="updateNotification",
)
async def update_notification(
    notification_id: str,
    payload: NotificationUpdateRequest,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> NotificationResponse:
    item = await NotificationService(session).mark_read(
        principal,
        notification_id,
        read=payload.read,
    )
    return _response(item)


@router.post(
    "/notifications/mark-all-read",
    response_model=MarkAllReadResponse,
    operation_id="markAllNotificationsRead",
)
async def mark_all_notifications_read(
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> MarkAllReadResponse:
    updated = await NotificationService(session).mark_all_read(principal)
    return MarkAllReadResponse(updated=updated)


@router.get(
    "/me/notification-preferences",
    response_model=NotificationPreferenceResponse,
    operation_id="getNotificationPreferences",
)
async def get_notification_preferences(
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> NotificationPreferenceResponse:
    preferences = await NotificationService(session).get_preferences(principal)
    return NotificationPreferenceResponse(
        recording_started=preferences.recording_started,
        recording_ready=preferences.recording_ready,
        recording_failed=preferences.recording_failed,
        updated_at=preferences.updated_at,
    )


@router.patch(
    "/me/notification-preferences",
    response_model=NotificationPreferenceResponse,
    operation_id="updateNotificationPreferences",
)
async def update_notification_preferences(
    payload: UpdateNotificationPreferencesRequest,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> NotificationPreferenceResponse:
    preferences = await NotificationService(session).update_preferences(
        principal,
        recording_started=payload.recording_started,
        recording_ready=payload.recording_ready,
        recording_failed=payload.recording_failed,
    )
    return NotificationPreferenceResponse(
        recording_started=preferences.recording_started,
        recording_ready=preferences.recording_ready,
        recording_failed=preferences.recording_failed,
        updated_at=preferences.updated_at,
    )
