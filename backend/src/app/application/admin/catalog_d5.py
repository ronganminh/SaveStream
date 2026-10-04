from __future__ import annotations

import base64
import json
import re
import uuid
from datetime import datetime, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.application.watches.resume import resume_credit_paused_watches
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.billing_models import (
    CreditPackage,
    PaymentOrder,
    PromotionCode,
    PromotionRedemption,
)
from app.infrastructure.db.credit_models import CreditAccount, CreditLedgerEntry
from app.infrastructure.db.models import User


_PROMO_PATTERN = re.compile(r"^[A-Z0-9][A-Z0-9_-]{2,63}$")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def _parse_uuid(value: str, label: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise ApplicationError(
            "RESOURCE_NOT_FOUND", f"{label} not found", status_code=404
        ) from exc


def _clean_optional(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


def _encode_cursor(created_at: datetime, row_id: uuid.UUID) -> str:
    payload = json.dumps(
        {"created_at": aware(created_at).isoformat(), "id": str(row_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")


def _decode_cursor(cursor: str) -> tuple[datetime, uuid.UUID]:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
        return datetime.fromisoformat(payload["created_at"]), uuid.UUID(payload["id"])
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        raise ApplicationError(
            "VALIDATION_ERROR", "Invalid pagination cursor", status_code=400
        ) from exc


async def grant_credits(
    session: AsyncSession,
    *,
    user_id: uuid.UUID,
    credits: int,
    reference_type: str,
    reference_id: str,
    reference_key: str,
    details: dict[str, object],
) -> CreditLedgerEntry:
    if credits <= 0:
        raise ApplicationError(
            "VALIDATION_ERROR", "Credit grant must be positive", status_code=400
        )
    existing = await session.scalar(
        select(CreditLedgerEntry).where(CreditLedgerEntry.reference_key == reference_key)
    )
    if existing is not None:
        return existing

    account = await session.scalar(
        select(CreditAccount)
        .where(CreditAccount.user_id == user_id)
        .with_for_update()
    )
    if account is None:
        account = CreditAccount(user_id=user_id, posted_balance=0)
        session.add(account)
        await session.flush()
    account.posted_balance += credits
    entry = CreditLedgerEntry(
        account_id=account.id,
        user_id=user_id,
        entry_type="grant",
        amount=credits,
        balance_after=account.posted_balance,
        reference_type=reference_type,
        reference_id=reference_id,
        reference_key=reference_key,
        details=details,
    )
    session.add(entry)
    await session.flush()
    await resume_credit_paused_watches(session, user_id)
    return entry


class AdminCatalogService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def packages(self) -> list[dict[str, object]]:
        order_count = (
            select(func.count(PaymentOrder.id))
            .where(PaymentOrder.package_id == CreditPackage.id)
            .correlate(CreditPackage)
            .scalar_subquery()
        )
        rows = list(
            (
                await self.session.execute(
                    select(CreditPackage, order_count.label("order_count"))
                    .order_by(
                        CreditPackage.display_order,
                        CreditPackage.credits,
                        CreditPackage.id,
                    )
                )
            ).all()
        )
        return [self._package_payload(row[0], int(row[1] or 0)) for row in rows]

    @staticmethod
    def _package_payload(package: CreditPackage, order_count: int) -> dict[str, object]:
        return {
            "id": str(package.id),
            "code": package.code,
            "name": package.name,
            "credits": package.credits,
            "amount_minor": package.amount_minor,
            "currency": package.currency,
            "active": package.active,
            "display_order": package.display_order,
            "app_store_product_id": package.app_store_product_id,
            "google_play_product_id": package.google_play_product_id,
            "web_variant_id": package.web_variant_id,
            "order_count": order_count,
            "created_at": package.created_at,
            "updated_at": package.updated_at,
        }

    async def _ensure_product_ids_unique(
        self,
        *,
        package_id: uuid.UUID | None,
        app_store_product_id: str | None,
        google_play_product_id: str | None,
        web_variant_id: str | None,
    ) -> None:
        checks = (
            ("App Store product ID", CreditPackage.app_store_product_id, app_store_product_id),
            ("Google Play product ID", CreditPackage.google_play_product_id, google_play_product_id),
            ("Web variant ID", CreditPackage.web_variant_id, web_variant_id),
        )
        for label, column, value in checks:
            if value is None:
                continue
            statement = select(CreditPackage.id).where(column == value)
            if package_id is not None:
                statement = statement.where(CreditPackage.id != package_id)
            if await self.session.scalar(statement) is not None:
                raise ApplicationError(
                    "CONFLICT",
                    f"{label} is already assigned to another package",
                    status_code=409,
                )

    async def create_package(
        self,
        *,
        code: str,
        name: str,
        credits: int,
        amount_minor: int,
        display_order: int,
        app_store_product_id: str | None,
        google_play_product_id: str | None,
        web_variant_id: str | None,
    ) -> dict[str, object]:
        normalized_code = code.strip().lower()
        if not normalized_code:
            raise ApplicationError(
                "VALIDATION_ERROR", "Package code is required", status_code=400
            )
        if await self.session.scalar(
            select(CreditPackage.id).where(CreditPackage.code == normalized_code)
        ) is not None:
            raise ApplicationError(
                "CONFLICT", "Package code already exists", status_code=409
            )
        app_id = _clean_optional(app_store_product_id)
        google_id = _clean_optional(google_play_product_id)
        variant_id = _clean_optional(web_variant_id)
        await self._ensure_product_ids_unique(
            package_id=None,
            app_store_product_id=app_id,
            google_play_product_id=google_id,
            web_variant_id=variant_id,
        )
        package = CreditPackage(
            code=normalized_code,
            name=name.strip(),
            credits=credits,
            amount_minor=amount_minor,
            currency="USD",
            active=True,
            display_order=display_order,
            app_store_product_id=app_id,
            google_play_product_id=google_id,
            web_variant_id=variant_id,
        )
        self.session.add(package)
        await self.session.flush()
        return self._package_payload(package, 0)

    async def update_package(
        self,
        package_id: str,
        *,
        name: str | None,
        credits: int | None,
        amount_minor: int | None,
        display_order: int | None,
        active: bool | None,
        app_store_product_id: str | None,
        google_play_product_id: str | None,
        web_variant_id: str | None,
        clear_app_store_product_id: bool,
        clear_google_play_product_id: bool,
        clear_web_variant_id: bool,
    ) -> tuple[dict[str, object], dict[str, object]]:
        parsed = _parse_uuid(package_id, "Credit package")
        package = await self.session.scalar(
            select(CreditPackage)
            .where(CreditPackage.id == parsed)
            .with_for_update()
        )
        if package is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Credit package not found", status_code=404
            )
        count = int(
            await self.session.scalar(
                select(func.count(PaymentOrder.id)).where(PaymentOrder.package_id == package.id)
            )
            or 0
        )
        before = self._package_payload(package, count)

        next_app = (
            None
            if clear_app_store_product_id
            else _clean_optional(app_store_product_id)
            if app_store_product_id is not None
            else package.app_store_product_id
        )
        next_google = (
            None
            if clear_google_play_product_id
            else _clean_optional(google_play_product_id)
            if google_play_product_id is not None
            else package.google_play_product_id
        )
        next_variant = (
            None
            if clear_web_variant_id
            else _clean_optional(web_variant_id)
            if web_variant_id is not None
            else package.web_variant_id
        )
        await self._ensure_product_ids_unique(
            package_id=package.id,
            app_store_product_id=next_app,
            google_play_product_id=next_google,
            web_variant_id=next_variant,
        )

        if name is not None:
            package.name = name.strip()
        if credits is not None:
            package.credits = credits
        if amount_minor is not None:
            package.amount_minor = amount_minor
        if display_order is not None:
            package.display_order = display_order
        if active is not None:
            package.active = active
        package.app_store_product_id = next_app
        package.google_play_product_id = next_google
        package.web_variant_id = next_variant
        await self.session.flush()
        return before, self._package_payload(package, count)

    async def promotions(self) -> list[dict[str, object]]:
        redemption_count = (
            select(func.count(PromotionRedemption.id))
            .where(PromotionRedemption.promotion_code_id == PromotionCode.id)
            .correlate(PromotionCode)
            .scalar_subquery()
        )
        rows = list(
            (
                await self.session.execute(
                    select(PromotionCode, redemption_count.label("redemption_count"))
                    .order_by(PromotionCode.created_at.desc(), PromotionCode.id.desc())
                )
            ).all()
        )
        return [
            self._promotion_payload(row[0], int(row[1] or 0))
            for row in rows
        ]

    @staticmethod
    def _promotion_payload(promo: PromotionCode, count: int) -> dict[str, object]:
        return {
            "id": str(promo.id),
            "code": promo.code,
            "credits": promo.credits,
            "expires_at": promo.expires_at,
            "max_redemptions": promo.max_redemptions,
            "redemption_count": count,
            "active": promo.active,
            "counts_as_purchase": promo.counts_as_purchase,
            "created_at": promo.created_at,
            "updated_at": promo.updated_at,
        }

    async def create_promotion(
        self,
        *,
        actor_user_id: uuid.UUID,
        code: str,
        credits: int,
        expires_at: datetime | None,
        max_redemptions: int | None,
        counts_as_purchase: bool,
    ) -> dict[str, object]:
        normalized = code.strip().upper()
        if not _PROMO_PATTERN.fullmatch(normalized):
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Promotion code must use A-Z, 0-9, underscore, or hyphen",
                status_code=400,
            )
        if expires_at is not None and aware(expires_at) <= utcnow():
            raise ApplicationError(
                "VALIDATION_ERROR", "Promotion expiry must be in the future", status_code=400
            )
        if await self.session.scalar(
            select(PromotionCode.id).where(PromotionCode.code == normalized)
        ) is not None:
            raise ApplicationError(
                "CONFLICT", "Promotion code already exists", status_code=409
            )
        promo = PromotionCode(
            code=normalized,
            credits=credits,
            expires_at=expires_at,
            max_redemptions=max_redemptions,
            active=True,
            counts_as_purchase=counts_as_purchase,
            created_by_user_id=actor_user_id,
        )
        self.session.add(promo)
        await self.session.flush()
        return self._promotion_payload(promo, 0)

    async def update_promotion(
        self,
        promotion_id: str,
        *,
        credits: int | None,
        expires_at: datetime | None,
        clear_expires_at: bool,
        max_redemptions: int | None,
        clear_max_redemptions: bool,
        active: bool | None,
        counts_as_purchase: bool | None,
    ) -> tuple[dict[str, object], dict[str, object]]:
        parsed = _parse_uuid(promotion_id, "Promotion")
        promo = await self.session.scalar(
            select(PromotionCode)
            .where(PromotionCode.id == parsed)
            .with_for_update()
        )
        if promo is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Promotion not found", status_code=404
            )
        count = int(
            await self.session.scalar(
                select(func.count(PromotionRedemption.id)).where(
                    PromotionRedemption.promotion_code_id == promo.id
                )
            )
            or 0
        )
        before = self._promotion_payload(promo, count)
        next_max = (
            None
            if clear_max_redemptions
            else max_redemptions
            if max_redemptions is not None
            else promo.max_redemptions
        )
        if next_max is not None and next_max < count:
            raise ApplicationError(
                "VALIDATION_ERROR",
                "Maximum redemptions cannot be below the number already redeemed",
                status_code=409,
            )
        next_expiry = (
            None
            if clear_expires_at
            else expires_at
            if expires_at is not None
            else promo.expires_at
        )
        if credits is not None:
            promo.credits = credits
        promo.expires_at = next_expiry
        promo.max_redemptions = next_max
        if active is not None:
            promo.active = active
        if counts_as_purchase is not None:
            promo.counts_as_purchase = counts_as_purchase
        await self.session.flush()
        return before, self._promotion_payload(promo, count)

    async def promotion_redemptions(
        self,
        promotion_id: str,
        *,
        limit: int,
        cursor: str | None,
    ) -> tuple[list[dict[str, object]], str | None, bool]:
        parsed = _parse_uuid(promotion_id, "Promotion")
        if await self.session.get(PromotionCode, parsed) is None:
            raise ApplicationError(
                "RESOURCE_NOT_FOUND", "Promotion not found", status_code=404
            )
        statement = (
            select(PromotionRedemption, User.email)
            .join(User, User.id == PromotionRedemption.user_id)
            .where(PromotionRedemption.promotion_code_id == parsed)
        )
        if cursor:
            created_at, row_id = _decode_cursor(cursor)
            statement = statement.where(
                or_(
                    PromotionRedemption.created_at < created_at,
                    and_(
                        PromotionRedemption.created_at == created_at,
                        PromotionRedemption.id < row_id,
                    ),
                )
            )
        rows = list(
            (
                await self.session.execute(
                    statement.order_by(
                        PromotionRedemption.created_at.desc(),
                        PromotionRedemption.id.desc(),
                    ).limit(limit + 1)
                )
            ).all()
        )
        has_more = len(rows) > limit
        selected = rows[:limit]
        items = [
            {
                "id": str(row[0].id),
                "user_id": str(row[0].user_id),
                "user_email": row[1],
                "ledger_entry_id": (
                    str(row[0].ledger_entry_id) if row[0].ledger_entry_id else None
                ),
                "created_at": row[0].created_at,
            }
            for row in selected
        ]
        next_cursor = (
            _encode_cursor(selected[-1][0].created_at, selected[-1][0].id)
            if has_more and selected
            else None
        )
        return items, next_cursor, has_more


class PromotionRedemptionService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def redeem(self, *, user_id: uuid.UUID, code: str) -> tuple[PromotionCode, CreditLedgerEntry]:
        normalized = code.strip().upper()
        promo = await self.session.scalar(
            select(PromotionCode)
            .where(PromotionCode.code == normalized)
            .with_for_update()
        )
        if promo is None or not promo.active:
            raise ApplicationError(
                "PROMOTION_INVALID", "Promotion code is invalid", status_code=404
            )
        if promo.expires_at is not None and aware(promo.expires_at) <= utcnow():
            raise ApplicationError(
                "PROMOTION_EXPIRED", "Promotion code has expired", status_code=409
            )
        if await self.session.scalar(
            select(PromotionRedemption.id).where(
                PromotionRedemption.promotion_code_id == promo.id,
                PromotionRedemption.user_id == user_id,
            )
        ) is not None:
            raise ApplicationError(
                "PROMOTION_ALREADY_REDEEMED",
                "Promotion code was already redeemed by this account",
                status_code=409,
            )
        if promo.max_redemptions is not None:
            count = int(
                await self.session.scalar(
                    select(func.count(PromotionRedemption.id)).where(
                        PromotionRedemption.promotion_code_id == promo.id
                    )
                )
                or 0
            )
            if count >= promo.max_redemptions:
                raise ApplicationError(
                    "PROMOTION_EXHAUSTED",
                    "Promotion code has reached its redemption limit",
                    status_code=409,
                )
        entry = await grant_credits(
            self.session,
            user_id=user_id,
            credits=promo.credits,
            reference_type="promotion",
            reference_id=str(promo.id),
            reference_key=f"promotion:{promo.id}:{user_id}",
            details={
                "source": "promotion",
                "promotion_code": promo.code,
                "counts_as_purchase": promo.counts_as_purchase,
            },
        )
        redemption = PromotionRedemption(
            promotion_code_id=promo.id,
            user_id=user_id,
            ledger_entry_id=entry.id,
        )
        self.session.add(redemption)
        await self.session.commit()
        await self.session.refresh(promo)
        return promo, entry
