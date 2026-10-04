from __future__ import annotations

import uuid
from urllib.parse import parse_qs

from app.application.rewards.ports import VerifiedRewardCallback
from app.domain.common.errors import ApplicationError


class FakeRewardVerifier:
    async def verify_callback(
        self,
        raw_query: bytes,
    ) -> VerifiedRewardCallback:
        values = parse_qs(raw_query.decode("utf-8"), keep_blank_values=True)
        try:
            reward_id = uuid.UUID(values["custom_data"][0])
            user_id = uuid.UUID(values["user_id"][0])
            transaction_id = values["transaction_id"][0]
        except (KeyError, IndexError, ValueError) as exc:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Invalid fake reward callback",
                status_code=400,
            ) from exc
        valid = values.get("valid", ["1"])[0].lower() not in {
            "0",
            "false",
            "no",
        }
        return VerifiedRewardCallback(
            reward_id=reward_id,
            user_id=user_id,
            transaction_id=transaction_id,
            valid=valid,
        )
