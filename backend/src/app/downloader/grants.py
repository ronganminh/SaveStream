"""Short-lived grants for owner downloads.

The API (which has the database and the user's session) checks which
verified channels the signed-in user owns and signs a grant listing them;
the downloader (which has neither) only verifies the signature. A grant
lives 60 seconds, so ownership is re-checked by the API for every resolve
and every file download.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from dataclasses import dataclass

GRANT_TTL_SECONDS = 60
MAX_GRANT_LENGTH = 4096


class InvalidGrant(Exception):
    pass


@dataclass(frozen=True, slots=True)
class Grant:
    user_id: str
    usernames: frozenset[str]
    tiktok_ids: frozenset[str]
    expires_at: int

    def owns(self, *, username: str | None, tiktok_id: str | None) -> bool:
        if tiktok_id and tiktok_id in self.tiktok_ids:
            return True
        return bool(username) and normalize(username or "") in self.usernames


def normalize(username: str) -> str:
    return username.strip().lstrip("@").casefold()


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def _sign(secret: str, body: str) -> str:
    return _b64(hmac.new(secret.encode(), b"vd-grant." + body.encode(), hashlib.sha256).digest())


def issue(
    secret: str,
    *,
    user_id: str,
    usernames: list[str],
    tiktok_ids: list[str],
    ttl_seconds: int = GRANT_TTL_SECONDS,
    now: float | None = None,
) -> str:
    if not secret:
        raise InvalidGrant("no grant secret configured")
    payload = {
        "u": user_id,
        "n": sorted({normalize(n) for n in usernames if n}),
        "i": sorted({i for i in tiktok_ids if i}),
        "exp": int((now if now is not None else time.time()) + ttl_seconds),
        "r": secrets.token_hex(4),
    }
    body = _b64(json.dumps(payload, separators=(",", ":")).encode())
    return f"{body}.{_sign(secret, body)}"


def verify(secret: str, token: str | None, *, now: float | None = None) -> Grant:
    if not secret or not token or len(token) > MAX_GRANT_LENGTH or "." not in token:
        raise InvalidGrant("missing or malformed grant")
    body, signature = token.rsplit(".", 1)
    if not hmac.compare_digest(_sign(secret, body), signature):
        raise InvalidGrant("bad signature")
    try:
        payload = json.loads(_unb64(body))
        grant = Grant(
            user_id=str(payload["u"]),
            usernames=frozenset(str(n) for n in payload["n"]),
            tiktok_ids=frozenset(str(i) for i in payload["i"]),
            expires_at=int(payload["exp"]),
        )
    except (ValueError, KeyError, TypeError) as exc:
        raise InvalidGrant("unreadable grant") from exc
    if grant.expires_at < (now if now is not None else time.time()):
        raise InvalidGrant("grant expired")
    return grant
