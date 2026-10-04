from __future__ import annotations

import base64
import time
import uuid
from urllib.parse import parse_qs

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec

from app.application.rewards.ports import VerifiedRewardCallback
from app.domain.common.errors import ApplicationError
from app.settings import AppSettings

_KEY_CACHE: tuple[float, dict[int, ec.EllipticCurvePublicKey]] | None = None
_KEY_CACHE_SECONDS = 86_400.0


def _decode_signature(value: str) -> bytes:
    padded = value + "=" * (-len(value) % 4)
    try:
        return base64.urlsafe_b64decode(padded.encode("ascii"))
    except (ValueError, UnicodeEncodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid AdMob signature encoding",
            status_code=400,
        ) from exc


class AdMobRewardVerifier:
    def __init__(
        self,
        settings: AppSettings,
        *,
        client: httpx.AsyncClient | None = None,
    ) -> None:
        self.settings = settings
        self.client = client

    async def _keys(self) -> dict[int, ec.EllipticCurvePublicKey]:
        global _KEY_CACHE
        now = time.monotonic()
        if _KEY_CACHE is not None and now - _KEY_CACHE[0] < _KEY_CACHE_SECONDS:
            return _KEY_CACHE[1]

        owns_client = self.client is None
        client = self.client or httpx.AsyncClient(
            timeout=self.settings.reward_verifier_timeout_seconds
        )
        try:
            response = await client.get(self.settings.admob_ssv_keys_url)
            response.raise_for_status()
            payload = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Unable to load AdMob verification keys",
                status_code=503,
                retryable=True,
            ) from exc
        finally:
            if owns_client:
                await client.aclose()

        keys: dict[int, ec.EllipticCurvePublicKey] = {}
        try:
            for item in payload["keys"]:
                key_id = int(item["keyId"])
                pem = item["pem"].encode("ascii")
                key = serialization.load_pem_public_key(pem)
                if not isinstance(key, ec.EllipticCurvePublicKey):
                    raise TypeError("AdMob key is not EC")
                keys[key_id] = key
        except (KeyError, TypeError, ValueError) as exc:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Invalid AdMob verification key set",
                status_code=503,
                retryable=True,
            ) from exc
        if not keys:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "AdMob verification key set is empty",
                status_code=503,
                retryable=True,
            )
        _KEY_CACHE = (now, keys)
        return keys

    async def verify_callback(
        self,
        raw_query: bytes,
    ) -> VerifiedRewardCallback:
        marker = b"&signature="
        index = raw_query.find(marker)
        if index < 0:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "AdMob callback is missing signature",
                status_code=400,
            )
        signed_content = raw_query[:index]
        values = parse_qs(raw_query.decode("utf-8"), keep_blank_values=True)
        try:
            reward_id = uuid.UUID(values["custom_data"][0])
            user_id = uuid.UUID(values["user_id"][0])
            transaction_id = values["transaction_id"][0]
            signature = _decode_signature(values["signature"][0])
            key_id = int(values["key_id"][0])
        except (KeyError, IndexError, ValueError) as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid AdMob callback payload",
                status_code=400,
            ) from exc

        key = (await self._keys()).get(key_id)
        if key is None:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Unknown AdMob verification key",
                status_code=400,
            )
        valid = True
        try:
            key.verify(
                signature,
                signed_content,
                ec.ECDSA(hashes.SHA256()),
            )
        except InvalidSignature:
            valid = False
        return VerifiedRewardCallback(
            reward_id=reward_id,
            user_id=user_id,
            transaction_id=transaction_id,
            valid=valid,
        )
