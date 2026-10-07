from __future__ import annotations

import base64
import json
import time
from typing import Any

import httpx
from Crypto.Hash import SHA256
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15

from app.application.notifications.push import (
    PushDeliveryError,
    PushMessage,
    PushTokenInvalid,
)
from app.settings import AppSettings

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_GRANT = "urn:ietf:params:oauth:grant-type:jwt-bearer"


def _b64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


class FcmPushSender:
    def __init__(
        self,
        settings: AppSettings,
        *,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.settings = settings
        self.transport = transport
        self._token: str | None = None
        self._token_expires_at = 0.0
        try:
            service_account = json.loads(settings.push_fcm_service_account_json)
        except json.JSONDecodeError as exc:
            raise ValueError("Invalid FCM service account JSON") from exc
        required = ("project_id", "client_email", "private_key")
        missing = [key for key in required if not service_account.get(key)]
        if missing:
            raise ValueError(
                "FCM service account is missing: " + ", ".join(missing)
            )
        self.project_id = str(service_account["project_id"])
        self.client_email = str(service_account["client_email"])
        self.private_key = str(service_account["private_key"])
        self.token_uri = str(
            service_account.get("token_uri") or settings.push_fcm_token_url
        )

    def _assertion(self) -> str:
        now = int(time.time())
        header = _b64url(
            json.dumps(
                {"alg": "RS256", "typ": "JWT"},
                separators=(",", ":"),
            ).encode("utf-8")
        )
        payload = _b64url(
            json.dumps(
                {
                    "iss": self.client_email,
                    "scope": _SCOPE,
                    "aud": self.token_uri,
                    "iat": now,
                    "exp": now + 3600,
                },
                separators=(",", ":"),
            ).encode("utf-8")
        )
        signing_input = f"{header}.{payload}".encode("ascii")
        key = RSA.import_key(self.private_key)
        signature = pkcs1_15.new(key).sign(SHA256.new(signing_input))
        return f"{header}.{payload}.{_b64url(signature)}"

    async def _access_token(self) -> str:
        now = time.time()
        if self._token and self._token_expires_at > now + 30:
            return self._token
        async with httpx.AsyncClient(
            transport=self.transport,
            timeout=self.settings.push_timeout_seconds,
        ) as client:
            response = await client.post(
                self.token_uri,
                data={
                    "grant_type": _GRANT,
                    "assertion": self._assertion(),
                },
            )
        if response.status_code >= 400:
            raise PushDeliveryError(
                f"FCM OAuth token request failed with HTTP {response.status_code}"
            )
        try:
            payload: dict[str, Any] = response.json()
            token = str(payload["access_token"])
            expires_in = int(payload.get("expires_in", 3600))
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
            raise PushDeliveryError("FCM OAuth token response is invalid") from exc
        self._token = token
        self._token_expires_at = now + max(1, expires_in - 60)
        return token

    async def send(self, push_token: str, message: PushMessage) -> None:
        access_token = await self._access_token()
        url = (
            f"{self.settings.push_fcm_base_url}/v1/projects/"
            f"{self.project_id}/messages:send"
        )
        async with httpx.AsyncClient(
            transport=self.transport,
            timeout=self.settings.push_timeout_seconds,
        ) as client:
            response = await client.post(
                url,
                headers={"Authorization": f"Bearer {access_token}"},
                json={
                    "message": {
                        "token": push_token,
                        "notification": {
                            "title": message.title,
                            "body": message.body,
                        },
                        "android": {
                            "notification": {
                                "channel_id": (
                                    "savestream_creator_live"
                                    if message.data.get("type") == "creator_live"
                                    else "savestream_recordings"
                                )
                            }
                        },
                        "data": message.data,
                    }
                },
            )
        if response.status_code < 400:
            return
        text = response.text.upper()
        if "UNREGISTERED" in text:
            raise PushTokenInvalid(push_token)
        raise PushDeliveryError(
            f"FCM send failed with HTTP {response.status_code}"
        )
