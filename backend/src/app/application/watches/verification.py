"""Channel ownership verification with a one-time code in the TikTok bio.

The user adds the channel, gets a code like ``SS-7K4Q``, pastes it anywhere
in the channel's bio and taps Check; the server reads the public profile and
looks for the code. Only verified channels may be recorded once a channel's
``verification_due_at`` has passed. Channels added before verification
existed got a grace period (migration 0032); new channels must verify first.
"""

from __future__ import annotations

import logging
import re
import secrets
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Literal, Protocol

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.schemas.recordings import Source
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.db.watch_models import ChannelVerification, Watch
from app.settings import AppSettings

logger = logging.getLogger(__name__)

# No 0/O, 1/I/L or U, so the code survives being retyped from a screen.
CODE_ALPHABET = "ABCDEFGHJKMNPQRSTVWXYZ23456789"
CODE_LENGTH = 4
MAX_CODES_PER_HOUR = 10

CheckResult = Literal["verified", "code_not_found", "retry_later"]
_NOT_CODE = re.compile(r"[^0-9A-Z]")
_PROFILE_URL = re.compile(
    r"^(?:https?://)?(?:www\.)?tiktok\.com/@([A-Za-z0-9._]{2,24})(?:[/?#].*)?$", re.IGNORECASE
)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def new_code() -> str:
    return "SS-" + "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))


def bio_contains_code(bio: str, code: str) -> bool:
    """Case, spaces and dashes don't matter: "ss 7k4q" matches "SS-7K4Q"."""
    return _NOT_CODE.sub("", code.upper()) in _NOT_CODE.sub("", bio.upper())


@dataclass(frozen=True, slots=True)
class ChannelProfile:
    username: str
    # None when TikTok's page did not include the bio (a login/WAF page).
    bio: str | None
    tiktok_user_id: str | None


class ChannelProfileLookup(Protocol):
    async def fetch(self, username: str) -> ChannelProfile | None: ...


def verification_required(watch: Watch, settings: AppSettings, now: datetime | None = None) -> bool:
    """True when this channel may not be recorded until its owner verifies it."""
    if not settings.channel_verification_enforced or watch.owner_verified_at is not None:
        return False
    due = watch.verification_due_at
    return due is None or _aware(due) <= (now or utcnow())


@dataclass(frozen=True, slots=True)
class VerificationState:
    watch: Watch
    code: str | None
    expires_at: datetime | None
    checks_left: int
    result: CheckResult | None = None
    retry_after_seconds: int | None = None


def _username_for_source(source: Source) -> str | None:
    if source.type == "username":
        return source.value.lstrip("@").casefold()
    if source.type == "url":
        match = _PROFILE_URL.match(source.value.strip())
        return match.group(1).casefold() if match else None
    return None


async def ensure_recording_source_verified(
    session: AsyncSession,
    settings: AppSettings,
    *,
    user_id: uuid.UUID,
    source: Source,
) -> None:
    """Refuse a recording unless it is one of the user's verified channels."""
    if not settings.channel_verification_enforced:
        return
    watches = list(
        (
            await session.scalars(
                select(Watch).where(Watch.user_id == user_id, Watch.deleted_at.is_(None))
            )
        ).all()
    )
    username = _username_for_source(source)
    room_id = source.value.strip() if source.type == "room_id" else None
    matches = [
        watch
        for watch in watches
        if (
            username is not None
            and username
            in {
                (watch.resolved_username or "").casefold(),
                watch.source_value.casefold() if watch.source_type == "username" else "",
            }
        )
        or (room_id is not None and watch.resolved_room_id == room_id)
    ]
    now = utcnow()
    if any(not verification_required(watch, settings, now) for watch in matches):
        return
    raise ApplicationError(
        "CHANNEL_NOT_VERIFIED",
        "Only channels you've verified as yours can be recorded. "
        "Add the channel and confirm it with the code in your bio.",
        status_code=403,
        retryable=False,
        details={"watch_id": str(matches[0].id)} if matches else None,
    )


class ChannelVerificationService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        *,
        lookup: ChannelProfileLookup | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.lookup = lookup

    async def _watch(self, principal: AuthPrincipal, watch_id: str) -> Watch:
        try:
            parsed = uuid.UUID(watch_id)
        except ValueError as exc:
            raise _not_found() from exc
        watch = await self.session.scalar(
            select(Watch).where(
                Watch.id == parsed,
                Watch.user_id == principal.user_id,
                Watch.deleted_at.is_(None),
            )
        )
        if watch is None:
            raise _not_found()
        return watch

    async def _pending(self, watch: Watch, now: datetime) -> ChannelVerification | None:
        row = await self.session.scalar(
            select(ChannelVerification)
            .where(
                ChannelVerification.watch_id == watch.id,
                ChannelVerification.status == "pending",
            )
            .order_by(ChannelVerification.created_at.desc())
            .limit(1)
        )
        if row is None:
            return None
        if _aware(row.expires_at) <= now or row.attempts >= self.settings.channel_verification_max_checks:
            row.status = "expired"
            await self.session.flush()
            return None
        return row

    def _state(self, watch: Watch, row: ChannelVerification | None, **extra) -> VerificationState:
        return VerificationState(
            watch=watch,
            code=row.code if row is not None else None,
            expires_at=row.expires_at if row is not None else None,
            checks_left=(
                max(0, self.settings.channel_verification_max_checks - row.attempts)
                if row is not None
                else 0
            ),
            **extra,
        )

    async def state(self, principal: AuthPrincipal, watch_id: str) -> VerificationState:
        watch = await self._watch(principal, watch_id)
        row = None if watch.owner_verified_at else await self._pending(watch, utcnow())
        await self.session.commit()
        return self._state(watch, row)

    async def start(self, principal: AuthPrincipal, watch_id: str) -> VerificationState:
        """Return the channel's current code, or a new one."""
        watch = await self._watch(principal, watch_id)
        if watch.owner_verified_at is not None:
            return self._state(watch, None, result="verified")
        username = watch.resolved_username or (
            watch.source_value if watch.source_type == "username" else None
        )
        if not username:
            raise ApplicationError(
                "VERIFICATION_UNSUPPORTED",
                "Only channels added by TikTok username can be verified",
                status_code=409,
            )
        now = utcnow()
        row = await self._pending(watch, now)
        if row is None:
            recent = int(
                await self.session.scalar(
                    select(func.count())
                    .select_from(ChannelVerification)
                    .where(
                        ChannelVerification.user_id == principal.user_id,
                        ChannelVerification.created_at >= now - timedelta(hours=1),
                    )
                )
                or 0
            )
            if recent >= MAX_CODES_PER_HOUR:
                raise ApplicationError(
                    "RATE_LIMITED",
                    "Too many verification codes. Try again in an hour.",
                    status_code=429,
                    retryable=True,
                )
            row = ChannelVerification(
                user_id=principal.user_id,
                watch_id=watch.id,
                username=username.lstrip("@").casefold(),
                code=new_code(),
                status="pending",
                attempts=0,
                expires_at=now + timedelta(seconds=self.settings.channel_verification_code_ttl_seconds),
                created_at=now,
            )
            self.session.add(row)
        await self.session.commit()
        await self.session.refresh(watch)
        return self._state(watch, row)

    async def check(self, principal: AuthPrincipal, watch_id: str) -> VerificationState:
        """Read the channel's bio from TikTok and look for the code."""
        watch = await self._watch(principal, watch_id)
        if watch.owner_verified_at is not None:
            return self._state(watch, None, result="verified")
        now = utcnow()
        row = await self._pending(watch, now)
        if row is None:
            await self.session.commit()
            raise ApplicationError(
                "VERIFICATION_EXPIRED",
                "This code has expired. Get a new code and try again.",
                status_code=409,
            )
        interval = self.settings.channel_verification_check_interval_seconds
        if row.last_checked_at is not None:
            waited = (now - _aware(row.last_checked_at)).total_seconds()
            if waited < interval:
                return self._state(
                    watch,
                    row,
                    result="retry_later",
                    retry_after_seconds=max(1, int(interval - waited + 0.999)),
                )
        row.attempts += 1
        row.last_checked_at = now
        profile = None
        if self.lookup is not None:
            try:
                profile = await self.lookup.fetch(row.username)
            except Exception:
                logger.info("Channel verification lookup failed", exc_info=True)
        if profile is None or profile.bio is None:
            # TikTok served a login/WAF page or failed: not the user's fault.
            row.last_result = "unavailable"
            await self.session.commit()
            return self._state(watch, row, result="retry_later", retry_after_seconds=interval)
        if not bio_contains_code(profile.bio, row.code):
            row.last_result = "code_not_found"
            await self.session.commit()
            return self._state(watch, row, result="code_not_found")
        row.status = "verified"
        row.last_result = "verified"
        row.verified_at = now
        row.tiktok_user_id = profile.tiktok_user_id
        mark_watch_verified(watch, method="bio_code", tiktok_user_id=profile.tiktok_user_id, now=now)
        await self.session.commit()
        await self.session.refresh(watch)
        return self._state(watch, None, result="verified")


def mark_watch_verified(
    watch: Watch,
    *,
    method: Literal["bio_code", "admin"],
    tiktok_user_id: str | None = None,
    now: datetime | None = None,
) -> None:
    watch.owner_verified_at = now or utcnow()
    watch.verification_method = method
    if tiktok_user_id:
        watch.owner_verified_tiktok_id = tiktok_user_id


def _not_found() -> ApplicationError:
    return ApplicationError("RESOURCE_NOT_FOUND", "Watch not found", status_code=404)
