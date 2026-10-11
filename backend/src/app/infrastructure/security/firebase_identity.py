from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any

from google.auth.exceptions import GoogleAuthError
from google.auth.transport.requests import Request
from google.oauth2 import id_token

from app.domain.common.errors import ApplicationError
from app.settings import AppSettings


@dataclass(frozen=True, slots=True)
class FirebasePrincipal:
    uid: str
    provider: str
    email: str | None
    email_verified: bool
    display_name: str | None


def _verify_signed_token(token: str, project_id: str) -> dict[str, Any]:
    """Validate the Firebase ID JWT signature using Google's public keys."""
    return id_token.verify_firebase_token(token, Request(), audience=project_id)


class FirebaseTokenVerifier:
    def __init__(self, settings: AppSettings) -> None:
        self.project_id = settings.firebase_auth_project_id

    async def verify(self, token: str) -> FirebasePrincipal:
        if not self.project_id:
            raise ApplicationError(
                "SOCIAL_AUTH_NOT_CONFIGURED",
                "Social sign-in is not enabled",
                status_code=503,
            )
        if not token or len(token) > 16384:
            raise self._invalid()
        try:
            claims = await asyncio.to_thread(_verify_signed_token, token, self.project_id)
        except (GoogleAuthError, ValueError, KeyError, TypeError, OSError) as exc:
            raise self._invalid() from exc

        firebase = claims.get("firebase")
        uid = claims.get("sub")
        provider = firebase.get("sign_in_provider") if isinstance(firebase, dict) else None
        if (
            claims.get("aud") != self.project_id
            or claims.get("iss") != f"https://securetoken.google.com/{self.project_id}"
            or not isinstance(uid, str)
            or not (1 <= len(uid) <= 128)
            or provider not in {"google.com", "apple.com"}
        ):
            raise self._invalid()
        email = claims.get("email")
        if email is not None and (
            not isinstance(email, str)
            or not 3 <= len(email) <= 320
            or "@" not in email
        ):
            raise self._invalid()
        name = claims.get("name")
        if not isinstance(name, str):
            name = None
        return FirebasePrincipal(
            uid=uid,
            provider=provider,
            email=email.strip() if email else None,
            email_verified=claims.get("email_verified") is True,
            display_name=name.strip()[:160] if name else None,
        )

    @staticmethod
    def _invalid() -> ApplicationError:
        return ApplicationError(
            "AUTH_SOCIAL_INVALID_TOKEN",
            "Invalid or expired sign-in token",
            status_code=401,
        )
