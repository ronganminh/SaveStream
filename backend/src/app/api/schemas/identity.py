from __future__ import annotations

import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


def _validate_email(value: str) -> str:
    normalized = value.strip()
    if len(normalized) > 320 or not _EMAIL_RE.fullmatch(normalized):
        raise ValueError("Invalid email address")
    return normalized


class LegalConsentRequest(StrictModel):
    """The user ticked "I am at least 18 and agree to the Terms and Privacy Policy"."""

    age_confirmed: Literal[True]
    terms_version: str = Field(min_length=1, max_length=32)
    privacy_version: str = Field(min_length=1, max_length=32)


class RegisterRequest(StrictModel):
    email: str
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=160)
    # Web sign-up must send consent. The paused mobile app predates this
    # and registers as "mobile" without it until it gets the same step.
    client_type: Literal["web", "mobile"] = "mobile"
    consent: LegalConsentRequest | None = None

    _email = field_validator("email")(_validate_email)


class AuthMessage(StrictModel):
    message: str


class VerifyEmailRequest(StrictModel):
    token: str = Field(min_length=16)


class EmailRequest(StrictModel):
    email: str

    _email = field_validator("email")(_validate_email)


class LoginRequest(StrictModel):
    email: str
    password: str = Field(min_length=1, max_length=128)
    client_type: Literal["web", "mobile"]

    _email = field_validator("email")(_validate_email)


class SocialLoginRequest(StrictModel):
    id_token: str = Field(min_length=20, max_length=16384)
    client_type: Literal["web", "mobile"]
    # Required when a web social sign-in would create a new account.
    consent: LegalConsentRequest | None = None


class SocialLinkRequest(StrictModel):
    id_token: str = Field(min_length=20, max_length=16384)
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(StrictModel):
    access_token: str
    token_type: Literal["Bearer"] = "Bearer"
    expires_in: int = Field(gt=0)
    refresh_token: str | None


class RefreshRequest(StrictModel):
    refresh_token: str | None = None


class ResetPasswordRequest(StrictModel):
    token: str = Field(min_length=16)
    password: str = Field(min_length=8, max_length=128)


class UpdateMeRequest(StrictModel):
    display_name: str | None = Field(default=None, max_length=160)
    locale: str | None = Field(default=None, min_length=2, max_length=16)


class UserResponse(StrictModel):
    id: str
    role: Literal["user", "owner", "support", "finance", "admin"]
    email: str
    email_verified: bool
    display_name: str | None
    locale: str
    created_at: datetime
    admin_mfa_enabled: bool = False
    admin_mfa_verified: bool = False


class SessionResponse(StrictModel):
    id: str
    created_at: datetime
    last_seen_at: datetime
    current: bool
    user_agent: str | None = None
    ip_hint: str | None = None


class SessionsResponse(StrictModel):
    items: list[SessionResponse]
