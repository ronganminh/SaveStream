from __future__ import annotations

from typing import Literal, cast

from fastapi import APIRouter, Depends, Query, Request

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.notifications import (
    EmailUnsubscribeRequest,
    EmailUnsubscribeResponse,
    MarkAllReadResponse,
    NotificationKind,
    NotificationListResponse,
    NotificationPreferenceResponse,
    NotificationResponse,
    NotificationUpdateRequest,
    UpdateNotificationPreferencesRequest,
)
from app.api.schemas.recordings import Pagination
from app.application.notifications.service import (
    PREFERENCE_FIELDS,
    NotificationPreferenceState,
    NotificationService,
)
from app.application.notifications.unsubscribe import EMAIL_LABELS, parse_token
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import NotificationPreference
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import UserNotification
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/v1", tags=["Notifications"])


def _preferences_response(state: NotificationPreferenceState) -> NotificationPreferenceResponse:
    return NotificationPreferenceResponse(
        **{field: getattr(state, field) for field in PREFERENCE_FIELDS},
        updated_at=state.updated_at,
    )


def _response(item: UserNotification) -> NotificationResponse:
    return NotificationResponse(
        id=str(item.id),
        type=cast(NotificationKind, item.kind),
        title=item.title,
        body=item.body,
        read=item.read_at is not None,
        resource_type=cast(Literal["recording", "watch"] | None, item.resource_type),
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
    return _preferences_response(preferences)


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
        principal, **payload.model_dump()
    )
    return _preferences_response(preferences)


@router.post(
    "/public/email/unsubscribe",
    response_model=EmailUnsubscribeResponse,
    operation_id="unsubscribeEmail",
)
async def unsubscribe_email(
    request: Request,
    token: str | None = Query(default=None, max_length=512),
    session: AsyncSession = Depends(get_db_session),
) -> EmailUnsubscribeResponse:
    """Turn off one kind of notification email from its signed link.

    The token comes from the JSON body (the /unsubscribe page) or the query
    string (RFC 8058 one-click: mail apps POST `List-Unsubscribe=One-Click`
    to the List-Unsubscribe URL). Idempotent.
    """
    if token is None and "json" in request.headers.get("content-type", ""):
        try:
            token = EmailUnsubscribeRequest.model_validate(await request.json()).token
        except ValueError as exc:
            raise ApplicationError(
                "VALIDATION_ERROR", "This unsubscribe link is not valid.", status_code=400
            ) from exc
    if not token:
        raise ApplicationError(
            "VALIDATION_ERROR", "This unsubscribe link is not valid.", status_code=400
        )
    user_id, preference = parse_token(request.app.state.settings.jwt_secret, token)
    row = await session.get(NotificationPreference, user_id)
    if row is None:
        row = NotificationPreference(user_id=user_id)
        session.add(row)
        await session.flush()
    setattr(row, preference, False)
    await session.commit()
    return EmailUnsubscribeResponse(preference=preference, label=EMAIL_LABELS[preference])
