from __future__ import annotations

import asyncio
import uuid

import pytest

from app.application.admin.catalog_d5 import (
    AdminCatalogService,
    PromotionRedemptionService,
)
from app.application.admin.service import AdminService
from app.application.billing.service import BillingService
from app.application.entitlements.service import EntitlementService
from app.domain.common.errors import ApplicationError
from app.infrastructure.db.models import Base, User
from app.infrastructure.db.session import Database
from app.infrastructure.payments.base import (
    CheckoutSession,
    ProviderEvent,
    ProviderPaymentState,
    ProviderRefundState,
    RefundSession,
)
from tests.identity_helpers import identity_settings


class CapturingProvider:
    name = "capture"

    def __init__(self) -> None:
        self.variant_id: str | None = None

    async def create_checkout(
        self,
        *,
        order_id: str,
        amount_minor: int,
        currency: str,
        return_url: str,
        variant_id: str | None = None,
    ) -> CheckoutSession:
        del amount_minor, currency, return_url
        self.variant_id = variant_id
        return CheckoutSession(
            provider_reference=f"capture:{order_id}",
            checkout_url=f"https://checkout.example/{order_id}",
        )

    async def create_refund(
        self,
        *,
        refund_id: str,
        provider_reference: str,
        amount_minor: int,
        currency: str,
    ) -> RefundSession:
        del provider_reference, amount_minor, currency
        return RefundSession(provider_refund_reference=f"refund:{refund_id}")

    async def retrieve_payment(
        self, provider_reference: str
    ) -> ProviderPaymentState | None:
        del provider_reference
        return None

    async def retrieve_refund(
        self, provider_refund_reference: str
    ) -> ProviderRefundState | None:
        del provider_refund_reference
        return None

    def verify_and_parse_webhook(
        self, raw_body: bytes, headers
    ) -> ProviderEvent:
        del raw_body, headers
        raise AssertionError("not used")


def test_d5_packages_promotions_and_purchase_flag(tmp_path) -> None:
    database_url = f"sqlite+aiosqlite:///{tmp_path / 'd5-policy.db'}"
    settings = identity_settings(database_url)

    async def run() -> None:
        database = Database(database_url)
        try:
            async with database.engine.begin() as connection:
                await connection.run_sync(Base.metadata.create_all)

            async with database.session() as session:
                admin = User(
                    email="owner-d5@example.com",
                    normalized_email="owner-d5@example.com",
                    role="owner",
                )
                free_user = User(
                    email="free-d5@example.com",
                    normalized_email="free-d5@example.com",
                    role="user",
                )
                pro_user = User(
                    email="pro-d5@example.com",
                    normalized_email="pro-d5@example.com",
                    role="user",
                )
                second_user = User(
                    email="second-d5@example.com",
                    normalized_email="second-d5@example.com",
                    role="user",
                )
                session.add_all([admin, free_user, pro_user, second_user])
                await session.flush()

                catalog = AdminCatalogService(session)
                package = await catalog.create_package(
                    code="starter-d5",
                    name="Starter D5",
                    credits=3000,
                    amount_minor=999,
                    display_order=2,
                    app_store_product_id="d5.app.starter",
                    google_play_product_id="d5.play.starter",
                    web_variant_id="variant-d5-starter",
                )
                await catalog.create_package(
                    code="first-d5",
                    name="First D5",
                    credits=1000,
                    amount_minor=399,
                    display_order=1,
                    app_store_product_id=None,
                    google_play_product_id=None,
                    web_variant_id=None,
                )
                await session.commit()

                provider = CapturingProvider()
                billing = BillingService(session, settings, provider)
                public_packages = await billing.packages()
                assert [item.code for item in public_packages[:2]] == [
                    "first-d5",
                    "starter-d5",
                ]
                order = await billing.create_order(
                    user_id=free_user.id,
                    package_id=str(package["id"]),
                    idempotency_key=str(uuid.uuid4()),
                )
                await billing.checkout(
                    user_id=free_user.id,
                    payment_order_id=str(order.id),
                    return_url="https://testserver/billing/success",
                    idempotency_key=str(uuid.uuid4()),
                )
                assert provider.variant_id == "variant-d5-starter"

                ordinary = await catalog.create_promotion(
                    actor_user_id=admin.id,
                    code="FREE60",
                    credits=60,
                    expires_at=None,
                    max_redemptions=1,
                    counts_as_purchase=False,
                )
                purchase = await catalog.create_promotion(
                    actor_user_id=admin.id,
                    code="PAID60",
                    credits=60,
                    expires_at=None,
                    max_redemptions=5,
                    counts_as_purchase=True,
                )
                await session.commit()

                promo_service = PromotionRedemptionService(session)
                await promo_service.redeem(user_id=free_user.id, code="free60")
                free_entitlement = await EntitlementService(session, settings).get(
                    free_user.id
                )
                assert free_entitlement.plan == "free"
                assert free_entitlement.has_purchased is False

                with pytest.raises(ApplicationError) as repeated:
                    await promo_service.redeem(user_id=free_user.id, code="FREE60")
                assert repeated.value.code == "PROMOTION_ALREADY_REDEEMED"

                with pytest.raises(ApplicationError) as exhausted:
                    await promo_service.redeem(user_id=second_user.id, code="FREE60")
                assert exhausted.value.code == "PROMOTION_EXHAUSTED"

                await promo_service.redeem(user_id=pro_user.id, code="paid60")
                pro_entitlement = await EntitlementService(session, settings).get(
                    pro_user.id
                )
                assert pro_entitlement.plan == "pro"
                assert pro_entitlement.has_purchased is True

                pro_page = await AdminService(session, settings).list_users(
                    limit=20,
                    cursor=None,
                    role="user",
                    is_active=None,
                    plan="pro",
                )
                assert str(pro_user.id) in {str(item.id) for item in pro_page.items}
                assert str(free_user.id) not in {
                    str(item.id) for item in pro_page.items
                }

                promos = await catalog.promotions()
                by_code = {item["code"]: item for item in promos}
                assert by_code[str(ordinary["code"])]["redemption_count"] == 1
                assert by_code[str(purchase["code"])]["redemption_count"] == 1
        finally:
            await database.close()

    asyncio.run(run())
