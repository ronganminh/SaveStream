from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Response, status

from app.api.dependencies import get_current_principal, get_identity_service
from app.api.schemas.identity import (
    AuthMessage,
    EmailRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.application.identity.service import IdentityService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1/auth", tags=["Auth"])


def _request_id(request: Request) -> str | None:
    return getattr(request.state, "request_id", None)


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


def _set_refresh_cookie(response: Response, request: Request, token: str) -> None:
    settings = request.app.state.settings
    response.set_cookie(
        key=settings.refresh_cookie_name,
        value=token,
        max_age=settings.refresh_token_ttl_seconds,
        path="/v1/auth",
        secure=True,
        httponly=True,
        samesite="lax",
    )


def _clear_refresh_cookie(response: Response, request: Request) -> None:
    response.delete_cookie(
        key=request.app.state.settings.refresh_cookie_name,
        path="/v1/auth",
        secure=True,
        httponly=True,
        samesite="lax",
    )


@router.post(
    "/register",
    response_model=AuthMessage,
    status_code=status.HTTP_201_CREATED,
    operation_id="registerAccount",
)
async def register(
    payload: RegisterRequest,
    request: Request,
    service: IdentityService = Depends(get_identity_service),
) -> AuthMessage:
    message = await service.register(
        email=payload.email,
        password=payload.password,
        display_name=payload.display_name,
        client_ip=_client_ip(request),
        request_id=_request_id(request),
    )
    return AuthMessage(message=message)


@router.post(
    "/verify-email",
    response_model=AuthMessage,
    operation_id="verifyEmail",
)
async def verify_email(
    payload: VerifyEmailRequest,
    request: Request,
    service: IdentityService = Depends(get_identity_service),
) -> AuthMessage:
    message = await service.verify_email(payload.token, request_id=_request_id(request))
    return AuthMessage(message=message)


@router.post(
    "/resend-verification",
    response_model=AuthMessage,
    operation_id="resendVerification",
)
async def resend_verification(
    payload: EmailRequest,
    request: Request,
    service: IdentityService = Depends(get_identity_service),
) -> AuthMessage:
    message = await service.resend_verification(
        email=payload.email,
        client_ip=_client_ip(request),
        request_id=_request_id(request),
    )
    return AuthMessage(message=message)


@router.post("/login", response_model=TokenResponse, operation_id="login")
async def login(
    payload: LoginRequest,
    request: Request,
    response: Response,
    service: IdentityService = Depends(get_identity_service),
) -> TokenResponse:
    result = await service.login(
        email=payload.email,
        password=payload.password,
        client_type=payload.client_type,
        client_ip=_client_ip(request),
        user_agent=request.headers.get("user-agent"),
        request_id=_request_id(request),
    )
    refresh_token: str | None = result.refresh_token
    if payload.client_type == "web":
        _set_refresh_cookie(response, request, result.refresh_token)
        refresh_token = None
    return TokenResponse(
        access_token=result.access_token,
        expires_in=result.expires_in,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=TokenResponse, operation_id="refreshToken")
async def refresh(
    payload: RefreshRequest,
    request: Request,
    response: Response,
    service: IdentityService = Depends(get_identity_service),
) -> TokenResponse:
    cookie_name = request.app.state.settings.refresh_cookie_name
    raw_token = payload.refresh_token or request.cookies.get(cookie_name)
    if not raw_token:
        raise ApplicationError(
            "AUTH_SESSION_REVOKED",
            "Authentication session is invalid or revoked",
            status_code=401,
        )
    result = await service.refresh(raw_token, request_id=_request_id(request))
    is_web = payload.refresh_token is None
    refresh_token: str | None = result.refresh_token
    if is_web:
        _set_refresh_cookie(response, request, result.refresh_token)
        refresh_token = None
    return TokenResponse(
        access_token=result.access_token,
        expires_in=result.expires_in,
        refresh_token=refresh_token,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT, response_model=None, operation_id="logout")
async def logout(
    request: Request,
    response: Response,
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> None:
    await service.logout(principal, request_id=_request_id(request))
    _clear_refresh_cookie(response, request)


@router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="logoutAll",
)
async def logout_all(
    request: Request,
    response: Response,
    principal: AuthPrincipal = Depends(get_current_principal),
    service: IdentityService = Depends(get_identity_service),
) -> None:
    await service.logout_all(principal, request_id=_request_id(request))
    _clear_refresh_cookie(response, request)


@router.post(
    "/forgot-password",
    response_model=AuthMessage,
    operation_id="forgotPassword",
)
async def forgot_password(
    payload: EmailRequest,
    request: Request,
    service: IdentityService = Depends(get_identity_service),
) -> AuthMessage:
    message = await service.forgot_password(
        email=payload.email,
        client_ip=_client_ip(request),
        request_id=_request_id(request),
    )
    return AuthMessage(message=message)


@router.post(
    "/reset-password",
    response_model=AuthMessage,
    operation_id="resetPassword",
)
async def reset_password(
    payload: ResetPasswordRequest,
    request: Request,
    service: IdentityService = Depends(get_identity_service),
) -> AuthMessage:
    message = await service.reset_password(
        token=payload.token,
        password=payload.password,
        request_id=_request_id(request),
    )
    return AuthMessage(message=message)
