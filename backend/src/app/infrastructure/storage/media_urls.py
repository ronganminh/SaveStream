"""Signed links to the media delivery Worker (services/media-worker).

The Worker serves recordings from the R2 bucket through a binding and the
Cloudflare edge cache, instead of the S3 API endpoint that answered 503s.
A link is

    {media_base_url}/o/{key}?e={expiry}&cd={b64url Content-Disposition}&s={signature}

with signature = base64url(HMAC-SHA256(secret, "{path}\\n{expiry}\\n{cd}")).
The canonical string must stay identical to `canonical()` in the Worker.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import time
from urllib.parse import quote, urlencode

from app.settings import AppSettings

MIN_SECRET_LENGTH = 32


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def media_delivery_enabled(settings: AppSettings) -> bool:
    return bool(
        settings.media_base_url
        and len(settings.media_signing_secret) >= MIN_SECRET_LENGTH
    )


def media_signature(secret: str, path: str, expires: int, disposition: str) -> str:
    message = f"{path}\n{expires}\n{disposition}".encode()
    return _b64url(hmac.new(secret.encode(), message, hashlib.sha256).digest())


def signed_media_url(
    settings: AppSettings,
    storage_key: str,
    *,
    content_disposition: str | None = None,
    now: float | None = None,
) -> str:
    expires = int(now if now is not None else time.time()) + settings.artifact_presign_seconds
    path = "/o/" + quote(storage_key, safe="/")
    disposition = _b64url(content_disposition.encode()) if content_disposition else ""
    query = {"e": str(expires)}
    if disposition:
        query["cd"] = disposition
    query["s"] = media_signature(settings.media_signing_secret, path, expires, disposition)
    return f"{settings.media_base_url}{path}?{urlencode(query)}"


def media_avatar_url(settings: AppSettings, avatar_id: str) -> str:
    return f"{settings.media_base_url}/a/{avatar_id}"
