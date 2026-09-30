from __future__ import annotations

from enum import Enum

from app.domain.common.errors import ApplicationError


class WatchStatus(str, Enum):
    ACTIVE = "active"
    PAUSED = "paused"
    PAUSED_INSUFFICIENT_CREDIT = "paused_insufficient_credit"
    PAUSED_ERROR = "paused_error"
    DISABLED = "disabled"


USER_SETTABLE_WATCH_STATUSES = frozenset(
    {WatchStatus.ACTIVE, WatchStatus.PAUSED, WatchStatus.DISABLED}
)


def validate_user_status(value: str) -> WatchStatus:
    try:
        status = WatchStatus(value)
    except ValueError as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid Watch status", status_code=400
        ) from exc
    if status not in USER_SETTABLE_WATCH_STATUSES:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "This Watch status is managed by the backend",
            status_code=400,
        )
    return status


def can_resume(status: WatchStatus) -> bool:
    return status in {
        WatchStatus.PAUSED,
        WatchStatus.PAUSED_ERROR,
        WatchStatus.PAUSED_INSUFFICIENT_CREDIT,
    }
