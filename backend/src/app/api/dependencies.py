from __future__ import annotations

from collections.abc import AsyncIterator, Callable
from datetime import timezone

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.billing.service import BillingService
from app.application.credits.service import CreditService
from app.application.identity.service import IdentityService, utcnow
from app.application.pricing.service import PricingService
from app.application.recordings.service import RecordingService
from app.application.watches.service import WatchService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, is_admin_role, scopes_for_role
from app.infrastructure.db.models import AuthSession, User
from app.infrastructure.payments.factory import selected_payment_provider
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
    principal = AuthPrincipal(
        user_id=user.id,
        session_id=auth_session.id,
        role=user.role,
        scopes=scopes_for_role(user.role),
        admin_mfa_verified=(
            not is_admin_role(user.role)
            or auth_session.admin_mfa_verified_at is not None
        ),
    )
    if is_admin_role(user.role) and not principal.admin_mfa_verified:
        mfa_allowed_paths = {
            "/v1/me",
            "/v1/auth/logout",
            "/v1/auth/logout-all",
            "/v1/admin/security/mfa",
            "/v1/admin/security/mfa/setup",
            "/v1/admin/security/mfa/enable",
            "/v1/admin/security/mfa/verify",
        }
        if request.url.path not in mfa_allowed_paths:
            raise ApplicationError(
                "ADMIN_MFA_REQUIRED",
                "Admin MFA verification is required",
                status_code=403,
            )
    return principal


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


def get_recording_service(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> RecordingService:
    return RecordingService(
        session,
        request.app.state.settings,
    )


def get_watch_service(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> WatchService:
    return WatchService(session, request.app.state.settings)


def get_credit_service(
    session: AsyncSession = Depends(get_db_session),
) -> CreditService:
    return CreditService(session)


def get_pricing_service(
    session: AsyncSession = Depends(get_db_session),
) -> PricingService:
    return PricingService(session)


def get_billing_service(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> BillingService:
    return BillingService(
        session,
        request.app.state.settings,
        selected_payment_provider(request.app.state.settings),
    )
