from __future__ import annotations

from collections.abc import AsyncIterator, Callable
from datetime import timezone

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.identity.service import IdentityService, utcnow
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, scopes_for_role
from app.infrastructure.db.models import AuthSession, User
from app.infrastructure.security.tokens import TokenError, TokenExpiredError, TokenService

_bearer = HTTPBearer(auto_error=False)


async def get_db_session(request: Request) -> AsyncIterator[AsyncSession]:
    database = request.app.state.database
    async with database.session() as session:
        yield session


def get_identity_service(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> IdentityService:
    return IdentityService(
        session,
        request.app.state.settings,
        request.app.state.rate_limiter,
    )


async def get_current_principal(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: AsyncSession = Depends(get_db_session),
) -> AuthPrincipal:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise ApplicationError(
            "AUTH_SESSION_REVOKED",
            "Authentication is required",
            status_code=401,
        )

    tokens = TokenService(request.app.state.settings)
    try:
        claims = tokens.decode_access_token(credentials.credentials)
    except (TokenError, TokenExpiredError) as exc:
        raise ApplicationError(
            "AUTH_SESSION_REVOKED",
            "Authentication session is invalid or revoked",
            status_code=401,
        ) from exc

    auth_session = await session.get(AuthSession, claims.session_id)
    user = await session.get(User, claims.user_id)
    if (
        auth_session is None
        or user is None
        or auth_session.user_id != claims.user_id
        or auth_session.revoked_at is not None
        or not user.is_active
    ):
        raise ApplicationError(
            "AUTH_SESSION_REVOKED",
            "Authentication session is invalid or revoked",
            status_code=401,
        )
    expires_at = auth_session.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= utcnow():
        raise ApplicationError(
            "AUTH_SESSION_REVOKED",
            "Authentication session is invalid or revoked",
            status_code=401,
        )
    return AuthPrincipal(
        user_id=user.id,
        session_id=auth_session.id,
        role=user.role,
        scopes=scopes_for_role(user.role),
    )


def require_scopes(*required: str) -> Callable:
    async def dependency(
        principal: AuthPrincipal = Depends(get_current_principal),
    ) -> AuthPrincipal:
        missing = [
            scope
            for scope in required
            if scope not in principal.scopes and "admin:*" not in principal.scopes
        ]
        if missing:
            raise ApplicationError(
                "FORBIDDEN",
                "Required permission is missing",
                status_code=403,
                details={"missing_scopes": missing},
            )
        return principal

    return dependency
