from __future__ import annotations

from typing import cast

from fastapi import APIRouter, Depends, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import get_current_principal, get_db_session
from app.api.schemas.local_recordings import (
    CreateRewardRequest,
    RewardCreateResponse,
    RewardStatus,
    RewardStatusResponse,
)
from app.application.rewards.service import RewardService
from app.domain.common.errors import ApplicationError
from app.domain.identity.types import AuthPrincipal
from app.infrastructure.rewards.factory import build_reward_verifier

router = APIRouter(prefix="/v1", tags=["Rewards"])


@router.post(
    "/rewards",
    response_model=RewardCreateResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createReward",
)
async def create_reward(
    payload: CreateRewardRequest,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RewardCreateResponse:
    reward = await RewardService(
        session,
        request.app.state.settings,
    ).create(principal.user_id, payload)
    return RewardCreateResponse(
        reward_id=str(reward.id),
        ssv_user_id=str(principal.user_id),
        ssv_custom_data=str(reward.id),
        expires_at=reward.expires_at,
    )


@router.get(
    "/rewards/{reward_id}",
    response_model=RewardStatusResponse,
    operation_id="getReward",
)
async def get_reward(
    reward_id: str,
    request: Request,
    principal: AuthPrincipal = Depends(get_current_principal),
    session: AsyncSession = Depends(get_db_session),
) -> RewardStatusResponse:
    reward = await RewardService(
        session,
        request.app.state.settings,
    ).get(principal.user_id, reward_id)
    return RewardStatusResponse(
        reward_id=str(reward.id),
        status=cast(RewardStatus, reward.status),
    )


@router.get(
    "/webhooks/admob-ssv",
    status_code=status.HTTP_204_NO_CONTENT,
    response_model=None,
    operation_id="admobSsvWebhook",
)
async def admob_ssv_webhook(
    request: Request,
    session: AsyncSession = Depends(get_db_session),
) -> None:
    verifier = build_reward_verifier(request.app.state.settings)
    callback = await verifier.verify_callback(
        request.scope.get("query_string", b"")
    )
    await RewardService(
        session,
        request.app.state.settings,
    ).apply_callback(callback)
    if not callback.valid:
        raise ApplicationError(
            "VALIDATION_ERROR",
            "Invalid rewarded-ad callback signature",
            status_code=400,
        )
