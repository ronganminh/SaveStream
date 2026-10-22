"""Android v2 Credits screens: Play order id and the price the app saw.

- payment_orders.store_order_id: Google Play orderId (GPA.…) from
  purchases.products.get; null for promo codes and older orders until they
  are re-verified.
- payment_orders.client_price_amount_micros / client_price_currency: the
  Google Play price the app reported when it bought. Display only.

Revision ID: 0035_credits_api_gaps
Revises: 0034_rewarded_cloud_minutes
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0035_credits_api_gaps"
down_revision = "0034_rewarded_cloud_minutes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("payment_orders") as batch:
        batch.add_column(sa.Column("store_order_id", sa.String(length=255), nullable=True))
        batch.add_column(
            sa.Column("client_price_amount_micros", sa.BigInteger(), nullable=True)
        )
        batch.add_column(
            sa.Column("client_price_currency", sa.String(length=3), nullable=True)
        )


def downgrade() -> None:
    with op.batch_alter_table("payment_orders") as batch:
        batch.drop_column("client_price_currency")
        batch.drop_column("client_price_amount_micros")
        batch.drop_column("store_order_id")
