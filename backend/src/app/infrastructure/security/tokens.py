from __future__ import annotations

import hashlib
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import jwt

from app.settings import AppSettings


class TokenError(ValueError):
    pass


class TokenExpiredError(TokenError):
    pass


@dataclass(frozen=True, slots=True)
class AccessClaims:
    user_id: uuid.UUID
    session_id: uuid.UUID
    token_id: str


@dataclass(frozen=True, slots=True)
class OneTimeClaims:
    user_id: uuid.UUID
    token_id: uuid.UUID
    purpose: str


class TokenService:
    algorithm = "HS256"

    def __init__(self, settings: AppSettings) -> None:
        self.settings = settings

    def issue_access_token(
        self,
        *,
        user_id: uuid.UUID,
        session_id: uuid.UUID,
        now: datetime | None = None,
        ttl_seconds: int | None = None,
    ) -> tuple[str, int]:
        issued_at = now or datetime.now(timezone.utc)
        ttl = ttl_seconds or self.settings.access_token_ttl_seconds
        expires_at = issued_at + timedelta(seconds=ttl)
        token_id = uuid.uuid4().hex
        payload = {
            "sub": str(user_id),
            "sid": str(session_id),
            "jti": token_id,
            "typ": "access",
            "iat": issued_at,
            "exp": expires_at,
            "iss": self.settings.jwt_issuer,
            "aud": self.settings.jwt_audience,
        }
        token = jwt.encode(payload, self.settings.jwt_secret, algorithm=self.algorithm)
        return token, ttl

    def decode_access_token(self, token: str) -> AccessClaims:
        try:
            payload = jwt.decode(
                token,
                self.settings.jwt_secret,
                algorithms=[self.algorithm],
                issuer=self.settings.jwt_issuer,
                audience=self.settings.jwt_audience,
                options={"require": ["sub", "sid", "jti", "typ", "iat", "exp"]},
            )
        except jwt.ExpiredSignatureError as exc:
            raise TokenExpiredError("access token expired") from exc
        except jwt.InvalidTokenError as exc:
            raise TokenError("invalid access token") from exc
        if payload.get("typ") != "access":
            raise TokenError("invalid token type")
        try:
            return AccessClaims(
                user_id=uuid.UUID(str(payload["sub"])),
                session_id=uuid.UUID(str(payload["sid"])),
                token_id=str(payload["jti"]),
            )
        except (KeyError, ValueError) as exc:
            raise TokenError("invalid access claims") from exc

    @staticmethod
    def _refresh_secret() -> str:
        return secrets.token_urlsafe(48)

    @staticmethod
    def hash_refresh_secret(secret: str) -> str:
        return hashlib.sha256(secret.encode("utf-8")).hexdigest()

    def issue_refresh_token(self, session_id: uuid.UUID) -> tuple[str, str]:
        secret = self._refresh_secret()
        token = f"rt_{session_id.hex}.{secret}"
        return token, self.hash_refresh_secret(secret)

    def parse_refresh_token(self, token: str) -> tuple[uuid.UUID, str]:
        try:
            prefix_and_id, secret = token.split(".", 1)
            if not prefix_and_id.startswith("rt_") or not secret:
                raise ValueError
            session_id = uuid.UUID(hex=prefix_and_id[3:])
        except (ValueError, AttributeError) as exc:
            raise TokenError("invalid refresh token") from exc
        return session_id, self.hash_refresh_secret(secret)

    def issue_one_time_token(
        self,
        *,
        token_id: uuid.UUID,
        user_id: uuid.UUID,
        purpose: str,
        issued_at: datetime,
        expires_at: datetime,
    ) -> str:
        payload = {
            "sub": str(user_id),
            "jti": str(token_id),
            "purpose": purpose,
            "typ": "one_time",
            "iat": issued_at,
            "exp": expires_at,
            "iss": self.settings.jwt_issuer,
            "aud": self.settings.jwt_audience,
        }
        return jwt.encode(payload, self.settings.jwt_secret, algorithm=self.algorithm)

    def decode_one_time_token(self, token: str, *, expected_purpose: str) -> OneTimeClaims:
        try:
            payload = jwt.decode(
                token,
                self.settings.jwt_secret,
                algorithms=[self.algorithm],
                issuer=self.settings.jwt_issuer,
                audience=self.settings.jwt_audience,
                options={"require": ["sub", "jti", "purpose", "typ", "iat", "exp"]},
            )
        except jwt.ExpiredSignatureError as exc:
            raise TokenExpiredError("one-time token expired") from exc
        except jwt.InvalidTokenError as exc:
            raise TokenError("invalid one-time token") from exc
        if payload.get("typ") != "one_time" or payload.get("purpose") != expected_purpose:
            raise TokenError("invalid one-time token purpose")
        try:
            return OneTimeClaims(
                user_id=uuid.UUID(str(payload["sub"])),
                token_id=uuid.UUID(str(payload["jti"])),
                purpose=str(payload["purpose"]),
            )
        except (KeyError, ValueError) as exc:
            raise TokenError("invalid one-time token claims") from exc
