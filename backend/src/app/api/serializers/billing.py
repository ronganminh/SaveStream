from app.api.schemas.billing import (
    CreditPackageResponse,
    Money,
    PaymentOrderResponse,
)
from app.infrastructure.db.billing_models import CreditPackage, PaymentOrder


def package_response(package: CreditPackage) -> CreditPackageResponse:
    return CreditPackageResponse(
        id=str(package.id),
        name=package.name,
        credits=package.credits,
        price=Money(
            amount_minor=package.amount_minor,
            currency=package.currency,
        ),
        active=package.active,
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
            "created_at": order.created_at,
            "updated_at": order.updated_at,
        }
    )
