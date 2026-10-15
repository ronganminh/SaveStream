"""Signed one-click unsubscribe links for notification emails.

A token names one email switch for one user and is signed with the JWT
secret (HMAC-SHA256), so it cannot be edited into another user or switch.
Tokens do not expire: an unsubscribe link must keep working.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import uuid

from app.application.notifications.service import EMAIL_PREFERENCE_FIELDS
from app.domain.common.errors import ApplicationError

EMAIL_LABELS: dict[str, str] = {
    "email_creator_live": "Channel went LIVE",
    "email_recording_ready": "Recording ready",
    "email_recording_failed": "Recording failed or missed",
    "email_recording_expiring": "Recording expiring soon",
    "email_credits_low": "Cloud credits running low",
    "email_credits_exhausted": "Cloud credits used up",
}


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _signature(secret: str, payload: str) -> str:
    return _b64(hmac.new(secret.encode(), f"unsubscribe:{payload}".encode(), hashlib.sha256).digest())[:32]


def make_token(secret: str, user_id: uuid.UUID, preference: str) -> str:
    if preference not in EMAIL_PREFERENCE_FIELDS:
        raise ValueError(f"Unknown email preference {preference}")
    payload = f"{user_id.hex}.{preference}"
    return f"{payload}.{_signature(secret, payload)}"


def parse_token(secret: str, token: str) -> tuple[uuid.UUID, str]:
    invalid = ApplicationError(
        "VALIDATION_ERROR", "This unsubscribe link is not valid.", status_code=400
    )
    parts = token.strip().split(".")
    if len(parts) != 3:
        raise invalid
    user_hex, preference, signature = parts
    payload = f"{user_hex}.{preference}"
    if not hmac.compare_digest(signature, _signature(secret, payload)):
        raise invalid
    if preference not in EMAIL_PREFERENCE_FIELDS:
        raise invalid
    try:
        return uuid.UUID(hex=user_hex), preference
    except ValueError as exc:
        raise invalid from exc
