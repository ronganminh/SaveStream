"""Add D3 recording retention override.

Revision ID: 0016_v2_d3_recording_retention
Revises: 0015_v2_d5_packages_promotions
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0016_v2_d3_recording_retention"
down_revision = "0015_v2_d5_packages_promotions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("recordings") as batch_op:
        batch_op.add_column(
            sa.Column("retention_expires_at", sa.DateTime(timezone=True), nullable=True)
        )

    op.create_table(
        "admin_watch_check_metrics",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("watch_id", sa.Uuid(), nullable=True),
        sa.Column("success", sa.Boolean(), nullable=False),
        sa.Column("latency_ms", sa.Integer(), nullable=False),
        sa.Column("error", sa.String(length=1000), nullable=True),
        sa.Column("checked_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["watch_id"], ["watches.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_admin_watch_check_metrics_checked",
        "admin_watch_check_metrics",
        ["checked_at"],
    )
    op.create_index(
        "ix_admin_watch_check_metrics_success_checked",
        "admin_watch_check_metrics",
        ["success", "checked_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_admin_watch_check_metrics_success_checked",
        table_name="admin_watch_check_metrics",
    )
    op.drop_index(
        "ix_admin_watch_check_metrics_checked",
        table_name="admin_watch_check_metrics",
    )
    op.drop_table("admin_watch_check_metrics")
    with op.batch_alter_table("recordings") as batch_op:
        batch_op.drop_column("retention_expires_at")
