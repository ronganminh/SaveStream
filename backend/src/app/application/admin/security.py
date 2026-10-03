from __future__ import annotations

import base64
import hashlib
import hmac
import io
import secrets
import struct
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from urllib.parse import quote

import qrcode
import qrcode.image.svg
from Crypto.Cipher import AES
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal, canonical_admin_role, is_admin_role
from app.infrastructure.db.admin_models import AdminMfaCredential, AdminStepUpGrant
from app.infrastructure.db.models import AuthSession, PasswordCredential, User
from app.infrastructure.security.passwords import PasswordService
from app.settings import AppSettings


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _encryption_key(settings: AppSettings) -> bytes:
    return hashlib.sha256(("admin-mfa:" + settings.jwt_secret).encode()).digest()


def encrypt_secret(settings: AppSettings, secret: str) -> str:
    nonce = secrets.token_bytes(12)
    cipher = AES.new(_encryption_key(settings), AES.MODE_GCM, nonce=nonce)
    ciphertext, tag = cipher.encrypt_and_digest(secret.encode())
    return base64.urlsafe_b64encode(nonce + tag + ciphertext).decode()


def decrypt_secret(settings: AppSettings, value: str) -> str:
    raw = base64.urlsafe_b64decode(value.encode())
    nonce, tag, ciphertext = raw[:12], raw[12:28], raw[28:]
    cipher = AES.new(_encryption_key(settings), AES.MODE_GCM, nonce=nonce)
    return cipher.decrypt_and_verify(ciphertext, tag).decode()


def generate_totp_secret() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def _totp(secret: str, counter: int) -> str:
    padded = secret + "=" * (-len(secret) % 8)
    key = base64.b32decode(padded, casefold=True)
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    value = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
    return f"{value % 1_000_000:06d}"


def verify_totp(secret: str, code: str, *, now: int | None = None) -> bool:
    if not code.isdigit() or len(code) != 6:
        return False
    counter = int((now or int(time.time())) // 30)
    return any(hmac.compare_digest(_totp(secret, counter + offset), code) for offset in (-1, 0, 1))


def recovery_hash(settings: AppSettings, code: str) -> str:
    return hmac.new(settings.jwt_secret.encode(), code.strip().upper().encode(), hashlib.sha256).hexdigest()


def make_recovery_codes() -> list[str]:
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return [
        "-".join("".join(secrets.choice(alphabet) for _ in range(4)) for _ in range(3))
        for _ in range(10)
    ]


def provisioning_uri(email: str, secret: str) -> str:
    issuer = "SaveStream"
    return (
        f"otpauth://totp/{quote(issuer)}:{quote(email)}"
        f"?secret={secret}&issuer={quote(issuer)}&algorithm=SHA1&digits=6&period=30"
    )


def provisioning_qr_svg(uri: str) -> str:
    image = qrcode.make(uri, image_factory=qrcode.image.svg.SvgPathImage)
    buffer = io.BytesIO()
    image.save(buffer)
    return buffer.getvalue().decode()


@dataclass(frozen=True, slots=True)
class MfaSetup:
    secret: str
    otpauth_uri: str
    qr_svg: str
    recovery_codes: list[str]


class AdminSecurityService:
    def __init__(self, session: AsyncSession, settings: AppSettings) -> None:
        self.session = session
        self.settings = settings
        self.passwords = PasswordService()

    async def status(self, principal: AuthPrincipal) -> tuple[bool, bool]:
        credential = await self.session.get(AdminMfaCredential, principal.user_id)
        return credential is not None and credential.enabled_at is not None, principal.admin_mfa_verified

    async def begin_setup(self, principal: AuthPrincipal) -> MfaSetup:
        user = await self.session.get(User, principal.user_id)
        if user is None or not is_admin_role(user.role):
            raise ApplicationError("FORBIDDEN", "Admin permission is required", status_code=403)
        secret = generate_totp_secret()
        codes = make_recovery_codes()
        row = await self.session.get(AdminMfaCredential, user.id)
        if row is None:
            row = AdminMfaCredential(user_id=user.id, encrypted_secret="", recovery_code_hashes=[])
            self.session.add(row)
        row.encrypted_secret = encrypt_secret(self.settings, secret)
        row.recovery_code_hashes = [recovery_hash(self.settings, code) for code in codes]
        row.enabled_at = None
        row.reset_at = utcnow()
        uri = provisioning_uri(user.email, secret)
        await self.session.commit()
        return MfaSetup(secret, uri, provisioning_qr_svg(uri), codes)

    async def enable(self, principal: AuthPrincipal, code: str) -> None:
        row = await self.session.get(AdminMfaCredential, principal.user_id)
        if row is None or not row.encrypted_secret:
            raise ApplicationError("VALIDATION_ERROR", "Start MFA setup first", status_code=409)
        if not verify_totp(decrypt_secret(self.settings, row.encrypted_secret), code):
            raise ApplicationError("AUTH_INVALID_MFA", "Invalid authentication code", status_code=401)
        row.enabled_at = utcnow()
        auth_session = await self.session.get(AuthSession, principal.session_id)
        if auth_session is not None:
            auth_session.admin_mfa_verified_at = utcnow()
        await self.session.commit()

    async def verify(self, principal: AuthPrincipal, code: str) -> None:
        row = await self.session.get(AdminMfaCredential, principal.user_id)
        if row is None or row.enabled_at is None:
            raise ApplicationError("ADMIN_MFA_SETUP_REQUIRED", "Admin MFA setup is required", status_code=403)
        valid = verify_totp(decrypt_secret(self.settings, row.encrypted_secret), code)
        if not valid:
            candidate = recovery_hash(self.settings, code)
            hashes = list(row.recovery_code_hashes or [])
            if candidate in hashes:
                hashes.remove(candidate)
                row.recovery_code_hashes = hashes
                valid = True
        if not valid:
            raise ApplicationError("AUTH_INVALID_MFA", "Invalid authentication code", status_code=401)
        auth_session = await self.session.get(AuthSession, principal.session_id)
        if auth_session is None:
            raise ApplicationError("AUTH_SESSION_REVOKED", "Authentication session is invalid", status_code=401)
        auth_session.admin_mfa_verified_at = utcnow()
        await self.session.commit()

    async def issue_step_up(
        self,
        principal: AuthPrincipal,
        *,
        password: str,
        code: str,
    ) -> tuple[str, datetime]:
        if not principal.admin_mfa_verified:
            raise ApplicationError("ADMIN_MFA_REQUIRED", "Admin MFA verification is required", status_code=403)
        credential = await self.session.get(PasswordCredential, principal.user_id)
        if credential is None or not self.passwords.verify(credential.password_hash, password):
            raise ApplicationError("AUTH_INVALID_CREDENTIALS", "Invalid email or password", status_code=401)
        mfa = await self.session.get(AdminMfaCredential, principal.user_id)
        if mfa is None or mfa.enabled_at is None or not verify_totp(
            decrypt_secret(self.settings, mfa.encrypted_secret), code
        ):
            raise ApplicationError("AUTH_INVALID_MFA", "Invalid authentication code", status_code=401)
        token = "asu_" + secrets.token_urlsafe(32)
        expires_at = utcnow() + timedelta(minutes=5)
        self.session.add(
            AdminStepUpGrant(
                user_id=principal.user_id,
                session_id=principal.session_id,
                token_hash=hashlib.sha256(token.encode()).hexdigest(),
                role=canonical_admin_role(principal.role),
                expires_at=expires_at,
            )
        )
        await self.session.commit()
        return token, expires_at

    async def verify_step_up(self, principal: AuthPrincipal, token: str) -> AdminStepUpGrant:
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        row = await self.session.scalar(
            select(AdminStepUpGrant).where(
                AdminStepUpGrant.token_hash == token_hash,
                AdminStepUpGrant.user_id == principal.user_id,
                AdminStepUpGrant.session_id == principal.session_id,
            )
        )
        if row is None or row.consumed_at is not None:
            raise ApplicationError("ADMIN_STEP_UP_REQUIRED", "Step-up authentication is required", status_code=403)
        expires_at = row.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at <= utcnow():
            raise ApplicationError("ADMIN_STEP_UP_REQUIRED", "Step-up authentication has expired", status_code=403)
        return row
