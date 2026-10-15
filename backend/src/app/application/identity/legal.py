"""Terms of Use / Privacy Policy (18+) and Acceptable Use Policy acceptance for new accounts."""

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
# "Last updated" date of /acceptable-use. Sign-up asks the user to confirm
# they will only record channels they own, manage or may record.
CURRENT_AUP_VERSION = "2026-10-05"


@dataclass(frozen=True, slots=True)
class ConsentInput:
    terms_version: str
    privacy_version: str
    age_confirmed: bool
    aup_accepted: bool = False
    aup_version: str | None = None


def _versions() -> dict[str, str]:
    return {
        "terms_version": CURRENT_TERMS_VERSION,
        "privacy_version": CURRENT_PRIVACY_VERSION,
        "aup_version": CURRENT_AUP_VERSION,
    }


def consent_required_error() -> ApplicationError:
    return ApplicationError(
        "LEGAL_CONSENT_REQUIRED",
        "Confirm that you are at least 18, agree to the Terms of Use and Privacy Policy, "
        "and will only record channels you own, manage or have permission to record",
        status_code=428,
        retryable=False,
        details=_versions(),
    )


def validate_consent(consent: ConsentInput | None) -> ConsentInput:
    """Reject a missing, partial or outdated acceptance before creating a user."""
    if consent is None or not consent.age_confirmed or not consent.aup_accepted:
        raise consent_required_error()
    if (
        consent.terms_version != CURRENT_TERMS_VERSION
        or consent.privacy_version != CURRENT_PRIVACY_VERSION
        or consent.aup_version != CURRENT_AUP_VERSION
    ):
        raise ApplicationError(
            "LEGAL_VERSION_OUTDATED",
            "The Terms of Use, Privacy Policy or Acceptable Use Policy changed. "
            "Reload the page and review them again",
            status_code=409,
            retryable=False,
            details=_versions(),
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
        aup_version=consent.aup_version if consent.aup_accepted else None,
        aup_accepted=consent.aup_accepted,
        method=method,
        ip_address=ip_address[:64],
        user_agent=(user_agent or None) and user_agent[:512],
    )
    session.add(row)
    return row
