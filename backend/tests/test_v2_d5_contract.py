from __future__ import annotations

import json
from pathlib import Path


OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "openapi.yaml"


def test_d5_catalog_promotions_openapi_contract() -> None:
    document = json.loads(OPENAPI.read_text(encoding="utf-8"))
    paths = document["paths"]
    expected = {
        "/admin/packages": ("get", "listAdminPackages"),
        "/admin/packages/{package_id}": ("patch", "updateAdminPackage"),
        "/admin/promotions": ("get", "listAdminPromotions"),
        "/admin/promotions/{promotion_id}": ("patch", "updateAdminPromotion"),
        "/admin/promotions/{promotion_id}/redemptions": (
            "get",
            "listAdminPromotionRedemptions",
        ),
        "/admin/bulk-grants/preview": ("post", "previewAdminBulkGrant"),
        "/admin/bulk-grants": ("post", "createAdminBulkGrant"),
        "/admin/bulk-grants/{grant_id}": ("get", "getAdminBulkGrant"),
        "/admin/bulk-grants/{grant_id}/deliveries": (
            "get",
            "listAdminBulkGrantDeliveries",
        ),
        "/credits/redeem": ("post", "redeemPromotion"),
    }
    for path, (method, operation_id) in expected.items():
        assert paths[path][method]["operationId"] == operation_id

    assert paths["/admin/packages"]["post"]["operationId"] == "createAdminPackage"
    assert paths["/admin/promotions"]["post"]["operationId"] == "createAdminPromotion"

    schemas = document["components"]["schemas"]
    for name in (
        "AdminPackage",
        "AdminPackageCreateRequest",
        "AdminPackageUpdateRequest",
        "AdminPromotion",
        "AdminPromotionCreateRequest",
        "AdminPromotionUpdateRequest",
        "AdminBulkGrantFilters",
        "AdminBulkGrantPreviewRequest",
        "AdminBulkGrantCreateRequest",
        "AdminBulkGrant",
        "RedeemPromotionRequest",
        "RedeemPromotionResponse",
    ):
        assert name in schemas

    for path, method in (
        ("/admin/packages", "post"),
        ("/admin/packages/{package_id}", "patch"),
        ("/admin/promotions", "post"),
        ("/admin/promotions/{promotion_id}", "patch"),
        ("/admin/bulk-grants", "post"),
    ):
        assert any(
            parameter["name"] == "X-Admin-Step-Up"
            for parameter in paths[path][method]["parameters"]
        )

    assert (
        schemas["AdminPromotionCreateRequest"]["properties"]["counts_as_purchase"]["default"]
        is False
    )
