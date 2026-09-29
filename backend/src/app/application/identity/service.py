from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.models import (
    AuditLog,
    AuthSession,
    OneTimeToken,
    PasswordCredential,
    User,
)
from app.infrastructure.queue.outbox import OutboxWriter
from app.infrastructure.rate_limit import RateLimiter
from app.infrastructure.security.passwords import PasswordService
from app.infrastructure.security.tokens import TokenError, TokenExpiredError, TokenService
from app.settings import AppSettings

REGISTER_MESSAGE = "If the address can be registered, verification instructions have been sent."
RESEND_MESSAGE = "If the account exists, verification instructions have been sent."
FORGOT_MESSAGE = "If the account exists, password reset instructions have been sent."


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def ip_hint(ip_address: str | None) -> str | None:
    if not ip_address:
        return None
    if ":" in ip_address:
        pieces = ip_address.split(":")
        return ":".join(pieces[:3]) + ":…"
    pieces = ip_address.split(".")
    if len(pieces) == 4:
        return ".".join(pieces[:2]) + ".x.x"
    return ip_address[:12] + "…"


@dataclass(frozen=True, slots=True)
class LoginResult:
    access_token: str
    expires_in: int
    refresh_token: str


class IdentityService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        rate_limiter: RateLimiter,
        *,
        password_service: PasswordService | None = None,
        token_service: TokenService | None = None,
        outbox_writer: OutboxWriter | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.rate_limiter = rate_limiter
        self.passwords = password_service or PasswordService()
        self.tokens = token_service or TokenService(settings)
        self.outbox = outbox_writer or OutboxWriter()

    @staticmethod
    def normalize_email(email: str) -> str:
        return email.strip().casefold()

    async def _rate_limit_auth_write(self, scope: str, identifier: str) -> None:
        await self.rate_limiter.hit(
            scope=scope,
            identifier=identifier,
            limit=self.settings.auth_write_rate_limit,
            window_seconds=self.settings.auth_write_rate_window_seconds,
        )

    async def _audit(
        self,
        *,
        action: str,
        user_id: uuid.UUID | None,
        request_id: str | None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        details: dict | None = None,
    ) -> None:
        self.session.add(
            AuditLog(
                actor_user_id=user_id,
                action=action,
                resource_type="user" if user_id else None,
                resource_id=str(user_id) if user_id else None,
                request_id=request_id,
                ip_address=ip_address,
                user_agent=user_agent,
                details=details or {},
            )
        )

    async def _issue_one_time_token(self, user: User, purpose: str) -> OneTimeToken:
        now = utcnow()
        await self.session.execute(
            update(OneTimeToken)
            .where(
                OneTimeToken.user_id == user.id,
                OneTimeToken.purpose == purpose,
                OneTimeToken.consumed_at.is_(None),
            )
            .values(consumed_at=now)
        )
        token = OneTimeToken(
            id=uuid.uuid4(),
            user_id=user.id,
            purpose=purpose,
            expires_at=now + timedelta(seconds=self.settings.one_time_token_ttl_seconds),
        )
        self.session.add(token)
        await self.session.flush()
        await self.outbox.enqueue(
            self.session,
            topic=f"identity.email.{purpose}",
            aggregate_type="user",
            aggregate_id=str(user.id),
            payload={"token_id": str(token.id)},
        )
        return token

    async def register(
        self,
        *,
        email: str,
        password: str,
        display_name: str | None,
        client_ip: str,
        request_id: str | None,
    ) -> str:
        normalized = self.normalize_email(email)
        await self._rate_limit_auth_write("register", f"{client_ip}|{normalized}")
        try:
            password_hash = self.passwords.hash(password)
        except ValueError as exc:
            raise ApplicationError("VALIDATION_ERROR", str(exc), status_code=400) from exc

        existing = await self.session.scalar(
            select(User).where(User.normalized_email == normalized)
        )
        if existing is not None:
            return REGISTER_MESSAGE

        user = User(
            email=email.strip(),
            normalized_email=normalized,
            display_name=display_name,
            locale="en",
            role="user",
        )
        self.session.add(user)
        await self.session.flush()
        self.session.add(
            PasswordCredential(user_id=user.id, password_hash=password_hash)
        )
        await self._issue_one_time_token(user, "verify_email")
        await self._audit(
            action="identity.registered",
            user_id=user.id,
            request_id=request_id,
            ip_address=client_ip,
        )
        await self.session.commit()
        return REGISTER_MESSAGE

    async def resend_verification(
        self,
        *,
        email: str,
        client_ip: str,
        request_id: str | None,
    ) -> str:
        normalized = self.normalize_email(email)
        await self._rate_limit_auth_write("resend_verification", f"{client_ip}|{normalized}")
        user = await self.session.scalar(
            select(User).where(User.normalized_email == normalized)
        )
        if user is not None and user.is_active and user.email_verified_at is None:
            await self._issue_one_time_token(user, "verify_email")
            await self._audit(
                action="identity.verification_resent",
                user_id=user.id,
                request_id=request_id,
                ip_address=client_ip,
            )
            await self.session.commit()
        return RESEND_MESSAGE

    async def verify_email(self, token: str, *, request_id: str | None) -> str:
        claims = self._decode_one_time(token, "verify_email")
        row = await self.session.get(OneTimeToken, claims.token_id)
        if (
            row is None
            or row.user_id != claims.user_id
            or row.purpose != "verify_email"
            or row.consumed_at is not None
            or aware(row.expires_at) <= utcnow()
        ):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid or expired verification token",
                status_code=400,
            )
        user = await self.session.get(User, claims.user_id)
        if user is None or not user.is_active:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid or expired verification token",
                status_code=400,
            )
        now = utcnow()
        user.email_verified_at = user.email_verified_at or now
        row.consumed_at = now
        await self._audit(
            action="identity.email_verified",
            user_id=user.id,
            request_id=request_id,
        )
        await self.session.commit()
        return "Email verified"

    async def login(
        self,
        *,
        email: str,
        password: str,
        client_type: str,
        client_ip: str,
        user_agent: str | None,
        request_id: str | None,
    ) -> LoginResult:
        normalized = self.normalize_email(email)
        await self.rate_limiter.hit(
            scope="login",
            identifier=f"{client_ip}|{normalized}",
            limit=self.settings.login_rate_limit,
            window_seconds=self.settings.login_rate_window_seconds,
        )
        statement = (
            select(User, PasswordCredential)
            .outerjoin(PasswordCredential, PasswordCredential.user_id == User.id)
            .where(User.normalized_email == normalized)
        )
        result = (await self.session.execute(statement)).first()
        user: User | None = result[0] if result else None
        credential: PasswordCredential | None = result[1] if result else None
        valid = self.passwords.verify(
            credential.password_hash if credential else None,
            password,
        )
        if user is None or credential is None or not valid or not user.is_active:
            raise ApplicationError(
                "AUTH_INVALID_CREDENTIALS",
                "Invalid email or password",
                status_code=401,
            )
        if user.email_verified_at is None:
            raise ApplicationError(
                "AUTH_EMAIL_NOT_VERIFIED",
                "Email verification is required",
                status_code=403,
            )
        if self.passwords.needs_rehash(credential.password_hash):
            credential.password_hash = self.passwords.hash(password)
            credential.updated_at = utcnow()

        session_id = uuid.uuid4()
        raw_refresh, refresh_hash = self.tokens.issue_refresh_token(session_id)
        now = utcnow()
        auth_session = AuthSession(
            id=session_id,
            user_id=user.id,
            token_family_id=uuid.uuid4(),
            client_type=client_type,
            refresh_token_hash=refresh_hash,
            refresh_history=[],
            user_agent=user_agent,
            ip_address=client_ip,
            expires_at=now + timedelta(seconds=self.settings.refresh_token_ttl_seconds),
        )
        self.session.add(auth_session)
        access_token, expires_in = self.tokens.issue_access_token(
            user_id=user.id,
            session_id=session_id,
        )
        await self._audit(
            action="identity.login",
            user_id=user.id,
            request_id=request_id,
            ip_address=client_ip,
            user_agent=user_agent,
            details={"client_type": client_type},
        )
        await self.session.commit()
        return LoginResult(access_token, expires_in, raw_refresh)

    async def refresh(self, raw_token: str, *, request_id: str | None) -> LoginResult:
        try:
            session_id, presented_hash = self.tokens.parse_refresh_token(raw_token)
        except TokenError as exc:
            raise self._session_revoked_error() from exc

        auth_session = await self.session.get(AuthSession, session_id)
        if auth_session is None:
            raise self._session_revoked_error()

        now = utcnow()
        if auth_session.revoked_at is not None or aware(auth_session.expires_at) <= now:
            raise self._session_revoked_error()

        if presented_hash != auth_session.refresh_token_hash:
            if presented_hash in list(auth_session.refresh_history or []):
                auth_session.revoked_at = now
                auth_session.revoked_reason = "refresh_reuse"
                await self._audit(
                    action="identity.refresh_reuse_detected",
                    user_id=auth_session.user_id,
                    request_id=request_id,
                    details={"session_id": str(auth_session.id)},
                )
                await self.session.commit()
            raise self._session_revoked_error()

        user = await self.session.get(User, auth_session.user_id)
        if user is None or not user.is_active:
            raise self._session_revoked_error()

        history = list(auth_session.refresh_history or [])
        history.append(auth_session.refresh_token_hash)
        raw_refresh, refresh_hash = self.tokens.issue_refresh_token(auth_session.id)
        auth_session.refresh_history = history
        auth_session.refresh_token_hash = refresh_hash
        auth_session.last_seen_at = now
        access_token, expires_in = self.tokens.issue_access_token(
            user_id=user.id,
            session_id=auth_session.id,
        )
        await self._audit(
            action="identity.refresh_rotated",
            user_id=user.id,
            request_id=request_id,
            details={"session_id": str(auth_session.id)},
        )
        await self.session.commit()
        return LoginResult(access_token, expires_in, raw_refresh)

    async def logout(self, principal: AuthPrincipal, *, request_id: str | None) -> None:
        auth_session = await self.session.get(AuthSession, principal.session_id)
        if auth_session is not None and auth_session.user_id == principal.user_id:
            auth_session.revoked_at = utcnow()
            auth_session.revoked_reason = "logout"
            await self._audit(
                action="identity.logout",
                user_id=principal.user_id,
                request_id=request_id,
                details={"session_id": str(principal.session_id)},
            )
            await self.session.commit()

    async def logout_all(self, principal: AuthPrincipal, *, request_id: str | None) -> None:
        now = utcnow()
        await self.session.execute(
            update(AuthSession)
            .where(
                AuthSession.user_id == principal.user_id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=now, revoked_reason="logout_all")
        )
        await self._audit(
            action="identity.logout_all",
            user_id=principal.user_id,
            request_id=request_id,
        )
        await self.session.commit()

    async def forgot_password(
        self,
        *,
        email: str,
        client_ip: str,
        request_id: str | None,
    ) -> str:
        normalized = self.normalize_email(email)
        await self._rate_limit_auth_write("forgot_password", f"{client_ip}|{normalized}")
        user = await self.session.scalar(
            select(User).where(User.normalized_email == normalized)
        )
        if user is not None and user.is_active:
            await self._issue_one_time_token(user, "password_reset")
            await self._audit(
                action="identity.password_reset_requested",
                user_id=user.id,
                request_id=request_id,
                ip_address=client_ip,
            )
            await self.session.commit()
        return FORGOT_MESSAGE

    async def reset_password(
        self,
        *,
        token: str,
        password: str,
        request_id: str | None,
    ) -> str:
        try:
            password_hash = self.passwords.hash(password)
        except ValueError as exc:
            raise ApplicationError("VALIDATION_ERROR", str(exc), status_code=400) from exc

        claims = self._decode_one_time(token, "password_reset")
        row = await self.session.get(OneTimeToken, claims.token_id)
        if (
            row is None
            or row.user_id != claims.user_id
            or row.purpose != "password_reset"
            or row.consumed_at is not None
            or aware(row.expires_at) <= utcnow()
        ):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid or expired password reset token",
                status_code=400,
            )
        credential = await self.session.get(PasswordCredential, claims.user_id)
        user = await self.session.get(User, claims.user_id)
        if credential is None or user is None or not user.is_active:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid or expired password reset token",
                status_code=400,
            )

        now = utcnow()
        credential.password_hash = password_hash
        credential.password_changed_at = now
        row.consumed_at = now
        await self.session.execute(
            update(AuthSession)
            .where(
                AuthSession.user_id == user.id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=now, revoked_reason="password_reset")
        )
        await self._audit(
            action="identity.password_reset",
            user_id=user.id,
            request_id=request_id,
        )
        await self.session.commit()
        return "Password reset completed"

    async def get_user(self, principal: AuthPrincipal) -> User:
        user = await self.session.get(User, principal.user_id)
        if user is None or not user.is_active:
            raise self._session_revoked_error()
        return user

    async def update_me(
        self,
        principal: AuthPrincipal,
        *,
        display_name: str | None,
        locale: str | None,
        request_id: str | None,
    ) -> User:
        user = await self.get_user(principal)
        user.display_name = display_name
        if locale is not None:
            user.locale = locale
        await self._audit(
            action="user.profile_updated",
            user_id=user.id,
            request_id=request_id,
        )
        await self.session.commit()
        await self.session.refresh(user)
        return user

    async def list_sessions(self, principal: AuthPrincipal) -> list[AuthSession]:
        statement = (
            select(AuthSession)
            .where(AuthSession.user_id == principal.user_id)
            .order_by(AuthSession.created_at.desc())
        )
        return list((await self.session.scalars(statement)).all())

    async def revoke_session(
        self,
        principal: AuthPrincipal,
        session_id: str,
        *,
        request_id: str | None,
    ) -> None:
        try:
            parsed = uuid.UUID(session_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Session not found", status_code=404
            ) from exc
        target = await self.session.scalar(
            select(AuthSession).where(
                AuthSession.id == parsed,
                AuthSession.user_id == principal.user_id,
            )
        )
        if target is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Session not found", status_code=404
            )
        if target.revoked_at is None:
            target.revoked_at = utcnow()
            target.revoked_reason = "session_revoke"
            await self._audit(
                action="identity.session_revoked",
                user_id=principal.user_id,
                request_id=request_id,
                details={"session_id": str(target.id)},
            )
            await self.session.commit()

    async def request_account_deletion(
        self,
        principal: AuthPrincipal,
        *,
        request_id: str | None,
    ) -> str:
        user = await self.get_user(principal)
        now = utcnow()
        user.deletion_requested_at = now
        user.is_active = False
        await self.session.execute(
            update(AuthSession)
            .where(
                AuthSession.user_id == user.id,
                AuthSession.revoked_at.is_(None),
            )
            .values(revoked_at=now, revoked_reason="account_deletion")
        )
        await self.outbox.enqueue(
            self.session,
            topic="identity.account_deletion_requested",
            aggregate_type="user",
            aggregate_id=str(user.id),
            payload={"user_id": str(user.id)},
        )
        await self._audit(
            action="user.account_deletion_requested",
            user_id=user.id,
            request_id=request_id,
        )
        await self.session.commit()
        return "Account deletion requested"

    def _decode_one_time(self, token: str, purpose: str):
        try:
            return self.tokens.decode_one_time_token(token, expected_purpose=purpose)
        except (TokenError, TokenExpiredError) as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid or expired token",
                status_code=400,
            ) from exc

    @staticmethod
    def _session_revoked_error() -> ApplicationError:
        return ApplicationError(
            "AUTH_SESSION_REVOKED",
            "Authentication session is invalid or revoked",
            status_code=401,
        )
