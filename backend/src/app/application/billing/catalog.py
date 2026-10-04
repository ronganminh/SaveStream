from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class StoreCatalogItem:
    code: str
    name: str
    credits: int
    amount_minor: int
    currency: str
    product_id: str

    @property
    def cloud_minutes(self) -> int:
        return self.credits


V2_STORE_CATALOG: tuple[StoreCatalogItem, ...] = (
    StoreCatalogItem(
        code="starter",
        name="Starter",
        credits=3_000,
        amount_minor=999,
        currency="USD",
        product_id="savestream.hours.50",
    ),
    StoreCatalogItem(
        code="standard",
        name="Standard",
        credits=9_000,
        amount_minor=2_499,
        currency="USD",
        product_id="savestream.hours.150",
    ),
    StoreCatalogItem(
        code="premium",
        name="Premium",
        credits=24_000,
        amount_minor=5_999,
        currency="USD",
        product_id="savestream.hours.400",
    ),
)

STORE_CATALOG_BY_PRODUCT_ID = {
    item.product_id: item for item in V2_STORE_CATALOG
}
