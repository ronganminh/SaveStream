from __future__ import annotations

from app.application.rewards.ports import RewardVerifier
from app.domain.common.errors import ApplicationError
from app.infrastructure.rewards.admob import AdMobRewardVerifier
from app.infrastructure.rewards.disabled import DisabledRewardVerifier
from app.infrastructure.rewards.fake import FakeRewardVerifier
from app.settings import AppSettings


def build_reward_verifier(settings: AppSettings) -> RewardVerifier:
    if settings.reward_provider == "disabled":
        return DisabledRewardVerifier()
    if settings.reward_provider == "fake":
        if settings.environment == "production":
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Fake reward verification is disabled in production",
                status_code=503,
            )
        return FakeRewardVerifier()
    if settings.reward_provider == "admob":
        return AdMobRewardVerifier(settings)
    raise ApplicationError(
        "SERVICE_UNAVAILABLE",
        "Unsupported reward verifier",
        status_code=503,
    )
