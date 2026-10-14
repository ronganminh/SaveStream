"""Public copyright / abuse reports from the /report page.

Each report becomes an admin complaint case (Admin → Safety) with
``created_by_user_id`` empty, so it is reviewed exactly like a case an
admin entered by hand. The form is anonymous, so it is rate limited per
IP and, when a Turnstile secret is configured, protected by Cloudflare
Turnstile.
"""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Awaitable, Callable

import httpx
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.creator_safety import normalize_creator_source
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import AdminComplaintCase, AdminComplaintEvent
from app.infrastructure.db.recording_models import Recording
from app.infrastructure.rate_limit import RateLimiter
from app.settings import AppSettings

TURNSTILE_VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

_RECORDING_ID = re.compile(
    r"recordings/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
    re.IGNORECASE,
)
_TIKTOK_URL_HANDLE = re.compile(r"tiktok\.com/@([A-Za-z0-9._]{2,24})", re.IGNORECASE)
_HANDLE = re.compile(r"(?:^|\s)@([A-Za-z0-9._]{2,24})\b")

TurnstileVerifier = Callable[[str, str], Awaitable[bool]]


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def report_reference(case_id: uuid.UUID) -> str:
    """Short reference shown to the reporter, e.g. ``SR-3F9A21C4``."""
    return "SR-" + case_id.hex[:8].upper()


@dataclass(frozen=True)
class ReportTarget:
    channel_username: str | None
    recording_id: uuid.UUID | None


def parse_target(text: str) -> ReportTarget:
    """Best effort: the first recording link, TikTok URL or @handle in ``text``."""
    recording = _RECORDING_ID.search(text)
    handle = _TIKTOK_URL_HANDLE.search(text) or _HANDLE.search(text)
    if handle is None:
        bare = text.strip().lstrip("@")
        if re.fullmatch(r"[A-Za-z0-9._]{2,24}", bare):
            return ReportTarget(channel_username=bare, recording_id=None)
    return ReportTarget(
        channel_username=handle.group(1) if handle else None,
        recording_id=uuid.UUID(recording.group(1)) if recording else None,
    )


async def verify_turnstile(secret: str, token: str, remote_ip: str) -> bool:
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                TURNSTILE_VERIFY_URL,
                data={"secret": secret, "response": token, "remoteip": remote_ip},
            )
        return bool(response.json().get("success"))
    except (httpx.HTTPError, ValueError):
        return False


class PublicReportService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        rate_limiter: RateLimiter,
        turnstile: TurnstileVerifier | None = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.rate_limiter = rate_limiter
        self.turnstile = turnstile or (
            lambda token, ip: verify_turnstile(settings.turnstile_secret_key, token, ip)
        )

    async def _guard(self, *, client_ip: str, turnstile_token: str | None) -> None:
        await self.rate_limiter.hit(
            scope="public_report",
            identifier=client_ip,
            limit=self.settings.public_report_rate_limit,
            window_seconds=self.settings.public_report_rate_window_seconds,
        )
        if not self.settings.turnstile_secret_key:
            return
        if not turnstile_token or not await self.turnstile(turnstile_token, client_ip):
            raise ApplicationError(
                "CAPTCHA_FAILED",
                "Please complete the verification and try again.",
                status_code=400,
            )

    async def reject_honeypot(self, *, client_ip: str) -> uuid.UUID:
        """A filled honeypot: count it against the rate limit, store nothing,
        and return a throwaway ID so the bot sees the normal success reply."""
        await self.rate_limiter.hit(
            scope="public_report",
            identifier=client_ip,
            limit=self.settings.public_report_rate_limit,
            window_seconds=self.settings.public_report_rate_window_seconds,
        )
        return uuid.uuid4()

    async def submit(
        self,
        *,
        kind: str,
        name: str,
        email: str,
        target_text: str,
        summary: str,
        body: str,
        client_ip: str,
        turnstile_token: str | None,
    ) -> AdminComplaintCase:
        await self._guard(client_ip=client_ip, turnstile_token=turnstile_token)

        target = parse_target(target_text)
        recording_id = target.recording_id
        if recording_id is not None and await self.session.get(Recording, recording_id) is None:
            # Unknown recording links stay in the report body for the reviewer.
            recording_id = None

        case = AdminComplaintCase(
            kind=kind,
            complainant_name=name.strip(),
            complainant_email=email.strip().casefold(),
            channel_source_type="username" if target.channel_username else None,
            channel_source_value=(
                normalize_creator_source("username", target.channel_username)
                if target.channel_username
                else None
            ),
            recording_id=recording_id,
            summary=summary.strip()[:240],
            body=body.strip(),
            status="new",
            created_by_user_id=None,
        )
        self.session.add(case)
        await self.session.flush()
        self.session.add(
            AdminComplaintEvent(
                complaint_id=case.id,
                actor_user_id=None,
                action="created",
                note="Submitted from the public report form.",
                metadata_json={"kind": kind, "source": "public_report_form"},
                created_at=utcnow(),
            )
        )
        await self.session.flush()
        return case
