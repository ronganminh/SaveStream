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
from collections.abc import Sequence
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.credits.service import CreditAdminService
from app.application.identity.legal import CURRENT_PRIVACY_VERSION, CURRENT_TERMS_VERSION
from app.application.public_reports import PublicReportService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.admin_models import PartnerApplication
from app.infrastructure.db.credit_models import CreditLedgerEntry
from app.infrastructure.db.models import User
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

# Partner Program reward: 50 recording hours (1 credit = 1 recording minute),
# granted once per application after its story is published.
REWARD_HOURS_DEFAULT = 50
CREDITS_PER_HOUR = 60
MAX_REWARD_HOURS = 500
_REWARD_NAMESPACE = uuid.UUID("6f1d9a52-3c4b-4f7e-9f8a-2b5c7d0e4a11")


def reward_idempotency_key(application_id: uuid.UUID) -> str:
    """Stable per application, so the ledger's unique reference key blocks a
    second grant even from two admins clicking at once."""
    return str(uuid.uuid5(_REWARD_NAMESPACE, f"partner-reward:{application_id}"))


def reward_reference_key(application_id: uuid.UUID) -> str:
    return f"admin-adjustment:{reward_idempotency_key(application_id)}"
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
        await self._queue_email(application, "partner_received")
        return application

    async def _queue_email(self, application: PartnerApplication, kind: str) -> None:
        from app.infrastructure.queue.outbox import OutboxWriter

        await OutboxWriter().enqueue(
            self.session,
            topic="partner.email",
            aggregate_type="partner_application",
            aggregate_id=str(application.id),
            payload={"application_id": str(application.id), "kind": kind},
        )

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

    async def published_stories(self, *, limit: int = 12) -> Sequence[PartnerApplication]:
        """Stories shown on the home page: published and consent not withdrawn."""
        rows = await self.session.scalars(
            select(PartnerApplication)
            .where(
                PartnerApplication.status == "published",
                PartnerApplication.consent_withdrawn_at.is_(None),
            )
            .order_by(PartnerApplication.published_at.desc())
            .limit(limit)
        )
        return rows.all()

    async def published_story(self, application_id: str) -> PartnerApplication:
        application = await self.get(application_id)
        if application.status != "published" or application.consent_withdrawn_at is not None:
            raise ApplicationError("RESOURCE_NOT_FOUND", "Story not found", status_code=404)
        return application

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
        if target == "approved" and before == "pending":
            # Re-approving after a rejection does not send it again (the
            # email log dedupes per application too).
            await self._queue_email(application, "partner_approved")
        await self.session.flush()
        await self.session.refresh(application)
        return application, before


    async def accounts_by_email(self, emails: Sequence[str]) -> dict[str, User]:
        if not emails:
            return {}
        users = (
            await self.session.scalars(
                select(User).where(User.normalized_email.in_({e.casefold() for e in emails}))
            )
        ).all()
        return {user.normalized_email: user for user in users}

    async def rewards(
        self, applications: Sequence[PartnerApplication]
    ) -> dict[uuid.UUID, CreditLedgerEntry]:
        keys = {reward_reference_key(item.id): item.id for item in applications}
        if not keys:
            return {}
        entries = (
            await self.session.scalars(
                select(CreditLedgerEntry).where(CreditLedgerEntry.reference_key.in_(keys))
            )
        ).all()
        return {keys[entry.reference_key]: entry for entry in entries}

    async def grant_reward(
        self, *, application_id: str, hours: int, reason: str
    ) -> tuple[PartnerApplication, User, CreditLedgerEntry]:
        application = await self.get(application_id)
        if application.status != "published":
            raise ApplicationError(
                "INVALID_STATE",
                "The reward is granted once the story is published.",
                status_code=409,
            )
        if not 1 <= hours <= MAX_REWARD_HOURS:
            raise ApplicationError(
                "VALIDATION_ERROR",
                f"Hours must be between 1 and {MAX_REWARD_HOURS}.",
                status_code=400,
            )
        if application.id in await self.rewards([application]):
            raise ApplicationError(
                "PARTNER_REWARD_ALREADY_GRANTED",
                "The reward for this application was already granted.",
                status_code=409,
            )
        user = (await self.accounts_by_email([application.email])).get(application.email)
        if user is None:
            raise ApplicationError(
                "PARTNER_ACCOUNT_NOT_FOUND",
                f"No SaveStream account uses {application.email}. "
                "Ask the creator to sign up with that email first.",
                status_code=409,
            )
        entry = await CreditAdminService(self.session).adjust(
            user_id=user.id,
            amount=hours * CREDITS_PER_HOUR,
            idempotency_key=reward_idempotency_key(application.id),
            reason=f"Partner Program reward ({hours} h): {reason}",
            commit=False,
        )
        return application, user, entry
