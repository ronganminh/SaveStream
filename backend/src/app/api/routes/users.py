from __future__ import annotations

from fastapi import APIRouter, Depends, Request, status

from app.api.dependencies import get_current_principal, get_identity_service
from app.api.schemas.identity import (
    AuthMessage,
    SessionResponse,
    SessionsResponse,
    UpdateMeRequest,
    UserResponse,
)
from app.application.identity.service import IdentityService, ip_hint
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import AuthSession, User

router = APIRouter(prefix="/v1", tags=["Users"])


def _request_id(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


def _user_response(user: User) -> UserResponse:
    return UserResponse(
        id=str(user.id),
        email=user.email,
        email_verified=user.email_verified_at is not None,
        display_name=user.display_name,
        locale=user.locale,
        created_at=user.created_at,
    )


def _session_response(
    auth_session: AuthSession,
    current_session_id,
) -> SessionResponse:
    return SessionResponse(
        id=str(auth_session.id),
        created_at=auth_session.created_at,
        last_seen_at=auth_session.last_seen_at,
        current=auth_session.id == current_session_id,
        user_agent=auth_session.user_agent,
        ip_hint=ip_hint(auth_session.ip_address),
    )


@router.get("/me", response_model=UserResponse, operation_id="getMe")
async def get_me(
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> UserResponse:
    return _user_response(await service.get_user(principal))


@router.patch("/me", response_model=UserResponse, operation_id="updateMe")
async def update_me(
    payload: UpdateMeRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> UserResponse:
    current = await service.get_user(principal)
    display_name = (
        payload.display_name
        if "display_name" in payload.model_fields_set
        else current.display_name
    )
    locale = payload.locale if "locale" in payload.model_fields_set else current.locale
    updated = await service.update_me(
        principal,
        display_name=display_name,
        locale=locale,
        request_id=_request_id(request),
    )
    return _user_response(updated)


@router.delete(
    "/me",
    response_model=AuthMessage,
    status_code=status.HTTP_202_ACCEPTED,
    operation_id="deleteMe",
)
async def delete_me(
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> AuthMessage:
    message = await service.request_account_deletion(
        principal,
        request_id=_request_id(request),
    )
    return AuthMessage(message=message)


@router.get(
    "/me/sessions",
    response_model=SessionsResponse,
    operation_id="listSessions",
)
async def list_sessions(
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> SessionsResponse:
    sessions = await service.list_sessions(principal)
    return SessionsResponse(
        items=[
            _session_response(item, principal.session_id)
            for item in sessions
        ]
    )


@router.delete(
    "/me/sessions/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    operation_id="revokeSession",
)
async def revoke_session(
    session_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> None:
    await service.revoke_session(
        principal,
        session_id,
        request_id=_request_id(request),
    )
