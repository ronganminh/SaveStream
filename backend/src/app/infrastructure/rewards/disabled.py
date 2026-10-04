from __future__ import annotations

from app.application.rewards.ports import VerifiedRewardCallback
from app.domain.common.errors import ApplicationError


class DisabledRewardVerifier:
    async def verify_callback(
        self,
        raw_query: bytes,
    ) -> VerifiedRewardCallback:
        del raw_query
        raise ApplicationError(
            "SERVICE_UNAVAILABLE",
            "Reward verification is disabled",
            status_code=503,
            retryable=True,
        )
