"""Account suspension / termination state.

Revision ID: 0031_account_status
Revises: 0030_notification_emails
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0031_account_status"
down_revision = "0030_notification_emails"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("account_status", sa.String(length=16), nullable=False, server_default="active"),
    )
    op.add_column("users", sa.Column("account_status_reason", sa.Text(), nullable=True))
    op.add_column("users", sa.Column("account_status_reference", sa.String(length=64), nullable=True))
    op.add_column(
        "users", sa.Column("account_status_changed_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    for column in (
        "account_status_changed_at",
        "account_status_reference",
        "account_status_reason",
        "account_status",
    ):
        op.drop_column("users", column)
