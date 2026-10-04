"""Add D9 admin overview aggregates and app support reports.

Revision ID: 0019_v2_d9_overview_reports
Revises: 0018_v2_d8_complaints_safety
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0019_v2_d9_overview_reports"
down_revision = "0018_v2_d8_complaints_safety"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_support_reports",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("recording_id", sa.Uuid(), nullable=True),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("diagnostic_log", sa.JSON(), nullable=False),
        sa.Column("app_version", sa.String(length=64), nullable=True),
        sa.Column("platform", sa.String(length=32), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("assigned_to_user_id", sa.Uuid(), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["recording_id"], ["recordings.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["assigned_to_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_support_reports_status_created", "admin_support_reports", ["status", "created_at"])
    op.create_index("ix_admin_support_reports_assignee_status", "admin_support_reports", ["assigned_to_user_id", "status"])
    op.create_index("ix_admin_support_reports_user_created", "admin_support_reports", ["user_id", "created_at"])
    op.create_index("ix_admin_support_reports_expires", "admin_support_reports", ["expires_at"])

    op.create_table(
        "admin_daily_metrics",
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("new_users", sa.Integer(), nullable=False),
        sa.Column("active_users_daily", sa.Integer(), nullable=False),
        sa.Column("active_users_weekly", sa.Integer(), nullable=False),
        sa.Column("active_users_monthly", sa.Integer(), nullable=False),
        sa.Column("free_users", sa.Integer(), nullable=False),
        sa.Column("pro_users", sa.Integer(), nullable=False),
        sa.Column("free_to_pro_weekly", sa.Integer(), nullable=False),
        sa.Column("revenue_web_usd_minor", sa.Integer(), nullable=False),
        sa.Column("revenue_app_store_usd_minor", sa.Integer(), nullable=False),
        sa.Column("revenue_google_play_usd_minor", sa.Integer(), nullable=False),
        sa.Column("estimated_store_fee_app_store_usd_minor", sa.Integer(), nullable=False),
        sa.Column("estimated_store_fee_google_play_usd_minor", sa.Integer(), nullable=False),
        sa.Column("recording_running", sa.Integer(), nullable=False),
        sa.Column("recording_waiting", sa.Integer(), nullable=False),
        sa.Column("recording_errors_24h", sa.Integer(), nullable=False),
        sa.Column("recording_total_24h", sa.Integer(), nullable=False),
        sa.Column("cloud_minutes_used", sa.Integer(), nullable=False),
        sa.Column("recording_status_counts", sa.JSON(), nullable=False),
        sa.Column("recording_capacity_limit", sa.Integer(), nullable=False),
        sa.Column("stuck_orders", sa.Integer(), nullable=False),
        sa.Column("open_complaints", sa.Integer(), nullable=False),
        sa.Column("computed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("day"),
    )


def downgrade() -> None:
    op.drop_table("admin_daily_metrics")
    op.drop_index("ix_admin_support_reports_expires", table_name="admin_support_reports")
    op.drop_index("ix_admin_support_reports_user_created", table_name="admin_support_reports")
    op.drop_index("ix_admin_support_reports_assignee_status", table_name="admin_support_reports")
    op.drop_index("ix_admin_support_reports_status_created", table_name="admin_support_reports")
    op.drop_table("admin_support_reports")
