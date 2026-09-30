from __future__ import annotations

import math
from typing import Any

from app.domain.common.errors import ApplicationError


class PricingEvaluator:
    """Evaluate a versioned pricing policy stored in PostgreSQL.

    Product pricing decisions are data, not route/worker constants. No policy is
    activated by migration. Admin/bootstrap tooling must explicitly create one.
    """

    @staticmethod
    def cost(
        *,
        policy_type: str,
        policy: dict[str, Any],
        duration_seconds: int,
        bytes_recorded: int,
    ) -> int:
        if duration_seconds < 0 or bytes_recorded < 0:
            raise ApplicationError(
                "INTERNAL_ERROR",
                "Pricing usage cannot be negative",
                status_code=500,
            )

        if policy_type == "duration_units_v1":
            unit_seconds = int(policy["unit_seconds"])
            credits_per_unit = int(policy["credits_per_unit"])
            minimum_credits = int(policy.get("minimum_credits", 0))
            if unit_seconds <= 0 or credits_per_unit < 0 or minimum_credits < 0:
                raise ApplicationError(
                    "INTERNAL_ERROR",
                    "Invalid active pricing policy",
                    status_code=500,
                )
            if duration_seconds == 0:
                return 0
            units = math.ceil(duration_seconds / unit_seconds)
            return max(minimum_credits, units * credits_per_unit)

        if policy_type == "flat_v1":
            amount = int(policy["credits"])
            if amount < 0:
                raise ApplicationError(
                    "INTERNAL_ERROR",
                    "Invalid active pricing policy",
                    status_code=500,
                )
            return amount if duration_seconds > 0 or bytes_recorded > 0 else 0

        raise ApplicationError(
            "SERVICE_UNAVAILABLE",
            "Active pricing policy type is not supported by this backend",
            status_code=503,
            retryable=False,
        )
