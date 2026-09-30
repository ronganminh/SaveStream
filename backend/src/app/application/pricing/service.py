from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.common.errors import ApplicationError
from app.infrastructure.db.credit_models import PricingRule, PricingSnapshot

from .policy import PricingEvaluator


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class PricingService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def active_rule(self) -> PricingRule:
        rule = await self.session.scalar(
            select(PricingRule)
            .where(
                PricingRule.is_active.is_(True),
                PricingRule.effective_from <= utcnow(),
            )
            .order_by(PricingRule.effective_from.desc(), PricingRule.created_at.desc())
            .limit(1)
        )
        if rule is None:
            raise ApplicationError(
                "SERVICE_UNAVAILABLE",
                "Pricing is not configured",
                status_code=503,
                retryable=False,
            )
        return rule

    async def snapshot(self, rule: PricingRule | None = None) -> PricingSnapshot:
        current = rule or await self.active_rule()
        snapshot = PricingSnapshot(
            pricing_rule_id=current.id,
            version=current.version,
            credit_unit=current.credit_unit,
            policy_type=current.policy_type,
            policy=dict(current.policy),
            public_rules=list(current.public_rules),
        )
        self.session.add(snapshot)
        await self.session.flush()
        return snapshot

    @staticmethod
    def estimate_max(snapshot: PricingSnapshot, max_duration_seconds: int) -> int:
        return PricingEvaluator.cost(
            policy_type=snapshot.policy_type,
            policy=snapshot.policy,
            duration_seconds=max_duration_seconds,
            bytes_recorded=0,
        )

    @staticmethod
    def actual_cost(
        snapshot: PricingSnapshot,
        *,
        duration_seconds: int,
        bytes_recorded: int,
    ) -> int:
        return PricingEvaluator.cost(
            policy_type=snapshot.policy_type,
            policy=snapshot.policy,
            duration_seconds=duration_seconds,
            bytes_recorded=bytes_recorded,
        )


class PricingAdminService:
    """Internal/admin application service. No unfrozen public route is added."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create_rule(
        self,
        *,
        version: str,
        policy_type: str,
        policy: dict[str, Any],
        public_rules: list[dict[str, Any]],
        activate: bool = False,
        effective_from: datetime | None = None,
    ) -> PricingRule:
        existing = await self.session.scalar(
            select(PricingRule).where(PricingRule.version == version)
        )
        if existing is not None:
            if activate and not existing.is_active:
                return await self.activate(version)
            return existing

        # Validate the configured policy without choosing product defaults.
        PricingEvaluator.cost(
            policy_type=policy_type,
            policy=policy,
            duration_seconds=1,
            bytes_recorded=1,
        )
        if activate:
            await self.session.execute(
                update(PricingRule).values(is_active=False)
            )
        rule = PricingRule(
            id=uuid.uuid4(),
            version=version,
            credit_unit="credit",
            policy_type=policy_type,
            policy=policy,
            public_rules=public_rules,
            is_active=activate,
            effective_from=effective_from or utcnow(),
        )
        self.session.add(rule)
        await self.session.commit()
        await self.session.refresh(rule)
        return rule

    async def activate(self, version: str) -> PricingRule:
        rule = await self.session.scalar(
            select(PricingRule).where(PricingRule.version == version)
        )
        if rule is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Pricing rule not found", status_code=404
            )
        await self.session.execute(update(PricingRule).values(is_active=False))
        rule.is_active = True
        rule.effective_from = utcnow()
        await self.session.commit()
        await self.session.refresh(rule)
        return rule
