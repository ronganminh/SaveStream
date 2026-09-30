from fastapi import APIRouter, Depends

from app.api.dependencies import get_pricing_service, require_scopes
from app.api.schemas.credits import PricingResponse
from app.application.pricing.service import PricingService
from app.domain.identity.types import AuthPrincipal

router = APIRouter(prefix="/v1", tags=["Credits"])


@router.get(
    "/pricing",
    response_model=PricingResponse,
    operation_id="getPricing",
)
async def get_pricing(
    principal: AuthPrincipal = Depends(require_scopes("credits:read")),
    service: PricingService = Depends(get_pricing_service),
) -> PricingResponse:
    del principal
    rule = await service.active_rule()
    return PricingResponse(
        version=rule.version,
        credit_unit="credit",
        rules=list(rule.public_rules),
    )
