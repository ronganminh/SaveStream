"""Terms of Use / Privacy Policy acceptance (18+) for new accounts."""

from __future__ import annotations

import uuid
from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import LegalConsent

# Revision dates of the published documents. Bump these together with the
# "Last updated" date on /terms and /privacy; clients must send the versions
# they showed the user.
CURRENT_TERMS_VERSION = "2026-10-14"
CURRENT_PRIVACY_VERSION = "2026-10-14"


@dataclass(frozen=True, slots=True)
class ConsentInput:
    terms_version: str
    privacy_version: str
    age_confirmed: bool


def consent_required_error() -> ApplicationError:
    return ApplicationError(
        "LEGAL_CONSENT_REQUIRED",
        "Confirm that you are at least 18 and agree to the Terms of Use and Privacy Policy",
        status_code=428,
        retryable=False,
        details={
            "terms_version": CURRENT_TERMS_VERSION,
            "privacy_version": CURRENT_PRIVACY_VERSION,
        },
    )


def validate_consent(consent: ConsentInput | None) -> ConsentInput:
    """Reject a missing, partial or outdated acceptance before creating a user."""
    if consent is None or not consent.age_confirmed:
        raise consent_required_error()
    if (
        consent.terms_version != CURRENT_TERMS_VERSION
        or consent.privacy_version != CURRENT_PRIVACY_VERSION
    ):
        raise ApplicationError(
            "LEGAL_VERSION_OUTDATED",
            "The Terms of Use or Privacy Policy changed. Reload the page and review them again",
            status_code=409,
            retryable=False,
            details={
                "terms_version": CURRENT_TERMS_VERSION,
                "privacy_version": CURRENT_PRIVACY_VERSION,
            },
        )
    return consent


def record_consent(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    consent: ConsentInput,
    method: str,
    ip_address: str,
    user_agent: str | None,
) -> LegalConsent:
    row = LegalConsent(
        user_id=user_id,
        terms_version=consent.terms_version,
        privacy_version=consent.privacy_version,
        age_confirmed=consent.age_confirmed,
        method=method,
        ip_address=ip_address[:64],
        user_agent=(user_agent or None) and user_agent[:512],
    )
    session.add(row)
    return row
