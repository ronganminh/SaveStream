from __future__ import annotations

import uuid
from dataclasses import dataclass
from typing import Protocol


@dataclass(frozen=True, slots=True)
class VerifiedRewardCallback:
    reward_id: uuid.UUID
    user_id: uuid.UUID
    transaction_id: str
    valid: bool


class RewardVerifier(Protocol):
    async def verify_callback(
        self,
        raw_query: bytes,
    ) -> VerifiedRewardCallback: ...
