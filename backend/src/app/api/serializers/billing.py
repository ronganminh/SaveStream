from collections.abc import Iterable

from app.api.schemas.billing import (
    CreditPackageResponse,
    Money,
    StoreProductIds,
    PaymentOrderResponse,
)
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder


def package_featured(package: CreditPackage, featured_codes: Iterable[str]) -> bool:
    return package.code.casefold() in {code.casefold() for code in featured_codes}


def package_response(
    package: CreditPackage, *, featured_codes: Iterable[str] = ()
) -> CreditPackageResponse:
    return CreditPackageResponse(
        id=str(package.id),
        name=package.name,
        credits=package.credits,
        price=Money(
            amount_minor=package.amount_minor,
            currency=package.currency,
        ),
        active=package.active,
        store_product_ids=(
            StoreProductIds(
                app_store=package.app_store_product_id,
                google_play=package.google_play_product_id,
            )
            # Each store's id stands alone: Android sells without an Apple id.
            if package.app_store_product_id or package.google_play_product_id
            else None
        ),
        cloud_minutes=package.credits,
        featured=package_featured(package, featured_codes),
    )


def payment_order_response(order: PaymentOrder) -> PaymentOrderResponse:
    return PaymentOrderResponse.model_validate(
        {
            "id": str(order.id),
            "package_id": str(order.package_id),
            "status": order.status,
            "credits": order.credits,
            "amount": {
                "amount_minor": order.amount_minor,
                "currency": order.currency,
            },
            "provider": order.provider,
            "provider_reference": order.provider_reference,
            "store_order_id": order.store_order_id,
            "client_price_amount_micros": order.client_price_amount_micros,
            "client_price_currency": order.client_price_currency,
            "created_at": order.created_at,
            "updated_at": order.updated_at,
        }
    )
