"""Google Play Billing for the Android v2 app.

- credit_accounts.refund_debt: store refunds that came after the credits were
  spent. It is paid off by the next purchase, and recording is blocked while
  it is above zero.
- payment_orders.store_token: the Google Play purchase token, kept so
  acknowledge/consume can be retried and pending purchases re-checked.

Revision ID: 0033_play_billing
Revises: 0032_channel_verification
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0033_play_billing"
down_revision = "0032_channel_verification"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("credit_accounts") as batch:
        batch.add_column(
            sa.Column("refund_debt", sa.Integer(), nullable=False, server_default="0")
        )
        batch.create_check_constraint(
            op.f("ck_credit_accounts_refund_debt_nonnegative"), "refund_debt >= 0"
        )
    op.add_column("payment_orders", sa.Column("store_token", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("payment_orders", "store_token")
    with op.batch_alter_table("credit_accounts") as batch:
        batch.drop_constraint(
            op.f("ck_credit_accounts_refund_debt_nonnegative"), type_="check"
        )
        batch.drop_column("refund_debt")
