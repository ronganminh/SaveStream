"""Sign-in error for suspended or terminated accounts (see
app.application.admin.account_status for how accounts get there)."""

from __future__ import annotations

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import User


def account_status_error(user: User) -> ApplicationError | None:
    """The sign-in error for a suspended or terminated account, else None."""
    if user.account_status not in ("suspended", "terminated"):
        return None
    suspended = user.account_status == "suspended"
    return ApplicationError(
        "ACCOUNT_SUSPENDED" if suspended else "ACCOUNT_TERMINATED",
        "This account is suspended" if suspended else "This account has been closed",
        status_code=403,
        retryable=False,
        details={
            "status": user.account_status,
            "reason": user.account_status_reason or "",
            "reference": user.account_status_reference or "",
            "since": user.account_status_changed_at.isoformat()
            if user.account_status_changed_at
            else "",
            "email": user.email,
        },
    )
