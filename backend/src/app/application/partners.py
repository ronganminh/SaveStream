"""Partner Program: applications from /partners/apply and admin review.

What may be published, and how consent is withdrawn, is described in
Privacy Policy section 10 ("Creator stories and Partner Program"). Each
application stores the exact confirmation texts the applicant checked, the
current Terms and Privacy versions, and the time, IP and user agent.
"""

from __future__ import annotations

import asyncio
import base64
import binascii
import re
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.identity.legal import CURRENT_PRIVACY_VERSION, CURRENT_TERMS_VERSION
from app.application.public_reports import PublicReportService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import PartnerApplication
from app.infrastructure.rate_limit import RateLimiter
from app.settings import AppSettings

# Shown next to the checkboxes on /partners/apply; stored verbatim.
CONSENT_OWNS_ACCOUNT = "I own or manage this TikTok account."
CONSENT_DISPLAY = (
    "I consent to SaveStream displaying my name, handle, image and clips on its website "
    "(revocable anytime by emailing support)."
)

NICHES = (
    "Fitness",
    "Gaming",
    "Music",
    "Beauty & fashion",
    "Food & cooking",
    "Education",
    "Shopping / live selling",
    "Other",
)
STATUSES = ("pending", "approved", "rejected", "published", "withdrawn")
MAX_PHOTO_BYTES = 5 * 1024 * 1024
_HANDLE = re.compile(r"^[A-Za-z0-9._]{2,24}$")
_PHOTO_TYPES = {b"\x89PNG\r\n\x1a\n": ("image/png", "png"), b"\xff\xd8\xff": ("image/jpeg", "jpg")}

# Which admin action moves an application into which status.
TRANSITIONS: dict[str, tuple[set[str], str]] = {
    "approve": ({"pending", "rejected"}, "approved"),
    "reject": ({"pending", "approved"}, "rejected"),
    "publish": ({"approved"}, "published"),
    "unpublish": ({"published", "approved", "pending"}, "withdrawn"),
}


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def photo_key(application_id: uuid.UUID, extension: str) -> str:
    return f"partner-photos/{application_id.hex}.{extension}"


def decode_photo(data_url: str) -> tuple[bytes, str, str]:
    """``data:image/...;base64,...`` → (bytes, content type, extension)."""
    _, _, encoded = data_url.partition(",")
    try:
        data = base64.b64decode(encoded or data_url, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "The photo could not be read.", status_code=400
        ) from exc
    if len(data) > MAX_PHOTO_BYTES:
        raise ApplicationError(
            "VALIDATION_ERROR", "The photo must be 5 MB or smaller.", status_code=400
        )
    for magic, (content_type, extension) in _PHOTO_TYPES.items():
        if data.startswith(magic):
            return data, content_type, extension
    raise ApplicationError(
        "VALIDATION_ERROR", "The photo must be a PNG or JPG image.", status_code=400
    )


class PartnerService:
    def __init__(
        self,
        session: AsyncSession,
        settings: AppSettings,
        rate_limiter: RateLimiter | None = None,
        storage: Any = None,
    ) -> None:
        self.session = session
        self.settings = settings
        self.rate_limiter = rate_limiter
        self.storage = storage

    def _guard(self) -> PublicReportService:
        # Same per-IP limit and Turnstile check as the public report form.
        assert self.rate_limiter is not None
        return PublicReportService(self.session, self.settings, self.rate_limiter)

    async def count_honeypot(self, *, client_ip: str) -> None:
        await self._guard().reject_honeypot(client_ip=client_ip)

    async def apply(
        self,
        *,
        name: str,
        email: str,
        tiktok_handle: str,
        other_channel_url: str | None,
        niche: str,
        story: str,
        photo_data_url: str | None,
        consent_owns_account: bool,
        consent_display: bool,
        client_ip: str,
        user_agent: str | None,
        turnstile_token: str | None,
    ) -> PartnerApplication:
        if not (consent_owns_account and consent_display):
            raise ApplicationError(
                "VALIDATION_ERROR", "Both confirmations are required.", status_code=400
            )
        handle = tiktok_handle.strip().lstrip("@")
        if not _HANDLE.fullmatch(handle):
            raise ApplicationError(
                "VALIDATION_ERROR", "Enter a valid TikTok handle.", status_code=400
            )
        if niche not in NICHES:
            raise ApplicationError("VALIDATION_ERROR", "Choose a niche.", status_code=400)
        photo = decode_photo(photo_data_url) if photo_data_url else None

        await self._guard()._guard(client_ip=client_ip, turnstile_token=turnstile_token)

        application = PartnerApplication(
            id=uuid.uuid4(),
            name=name.strip(),
            email=email.strip().casefold(),
            tiktok_handle=handle.casefold(),
            other_channel_url=(other_channel_url or "").strip() or None,
            niche=niche,
            story=story.strip(),
            status="pending",
            consent_owns_account=True,
            consent_display=True,
            consent_texts=[CONSENT_OWNS_ACCOUNT, CONSENT_DISPLAY],
            terms_version=CURRENT_TERMS_VERSION,
            privacy_version=CURRENT_PRIVACY_VERSION,
            consent_ip=client_ip[:64],
            consent_user_agent=(user_agent or "")[:512] or None,
        )
        if photo is not None:
            data, content_type, extension = photo
            key = photo_key(application.id, extension)
            await asyncio.to_thread(
                self.storage.upload_bytes, data, key, content_type=content_type
            )
            application.photo_key = key
            application.photo_content_type = content_type
        self.session.add(application)
        await self.session.flush()
        return application

    async def list(
        self, *, status: str | None, query: str | None, limit: int = 100
    ) -> tuple[list[PartnerApplication], dict[str, int]]:
        statement = select(PartnerApplication)
        if status:
            statement = statement.where(PartnerApplication.status == status)
        if query:
            like = f"%{query.strip().casefold().lstrip('@')}%"
            statement = statement.where(
                or_(
                    func.lower(PartnerApplication.name).like(like),
                    PartnerApplication.tiktok_handle.like(like),
                    PartnerApplication.email.like(like),
                )
            )
        rows = (
            await self.session.scalars(
                statement.order_by(PartnerApplication.created_at.desc()).limit(limit)
            )
        ).all()
        counts = {
            row_status: count
            for row_status, count in (
                await self.session.execute(
                    select(PartnerApplication.status, func.count()).group_by(
                        PartnerApplication.status
                    )
                )
            ).all()
        }
        return list(rows), counts

    async def get(self, application_id: str) -> PartnerApplication:
        try:
            parsed = uuid.UUID(application_id)
        except ValueError as exc:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Application not found", status_code=404
            ) from exc
        application = await self.session.get(PartnerApplication, parsed)
        if application is None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Application not found", status_code=404)
        return application

    async def transition(
        self, *, application_id: str, action: str, reviewer_id: uuid.UUID
    ) -> tuple[PartnerApplication, str]:
        if action not in TRANSITIONS:
            raise ApplicationError("VALIDATION_ERROR", "Unknown action", status_code=400)
        application = await self.get(application_id)
        allowed_from, target = TRANSITIONS[action]
        if application.status not in allowed_from:
            raise ApplicationError(
                "INVALID_STATE",
                f"Cannot {action} an application that is {application.status}.",
                status_code=409,
            )
        if action == "publish" and application.consent_withdrawn_at is not None:
            raise ApplicationError(
                "INVALID_STATE", "Consent was withdrawn; the story cannot be published.",
                status_code=409,
            )
        before = application.status
        application.status = target
        application.reviewed_by_user_id = reviewer_id
        if target == "published":
            application.published_at = utcnow()
        if target == "withdrawn":
            application.consent_withdrawn_at = application.consent_withdrawn_at or utcnow()
            application.published_at = None
        await self.session.flush()
        await self.session.refresh(application)
        return application, before
