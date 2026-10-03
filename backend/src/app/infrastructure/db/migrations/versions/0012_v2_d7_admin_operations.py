"""V2 D7 admin storage, email and broadcast operations."""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0012_v2_d7_admin_operations"
down_revision = "0011_v2_b3_devices_push"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_storage_runs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(length=48), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("scanned_count", sa.Integer(), nullable=False),
        sa.Column("orphan_count", sa.Integer(), nullable=False),
        sa.Column("deleted_count", sa.Integer(), nullable=False),
        sa.Column("details", sa.JSON(), nullable=False),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_storage_runs_kind_created", "admin_storage_runs", ["kind", "created_at"])
    op.create_index("ix_admin_storage_runs_status_created", "admin_storage_runs", ["status", "created_at"])

    op.create_table(
        "admin_email_templates",
        sa.Column("key", sa.String(length=64), nullable=False),
        sa.Column("subject", sa.String(length=240), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("updated_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["updated_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("key"),
    )

    op.create_table(
        "admin_email_logs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=True),
        sa.Column("recipient_email", sa.String(length=320), nullable=False),
        sa.Column("kind", sa.String(length=64), nullable=False),
        sa.Column("subject", sa.String(length=240), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("dedupe_key", sa.String(length=180), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("dedupe_key", name="uq_admin_email_logs_dedupe_key"),
    )
    op.create_index("ix_admin_email_logs_created", "admin_email_logs", ["created_at"])
    op.create_index("ix_admin_email_logs_recipient_created", "admin_email_logs", ["recipient_email", "created_at"])
    op.create_index("ix_admin_email_logs_kind_status", "admin_email_logs", ["kind", "status"])

    op.create_table(
        "admin_broadcasts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("kind", sa.String(length=24), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("channels", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("audience_count", sa.Integer(), nullable=False),
        sa.Column("delivered_in_app", sa.Integer(), nullable=False),
        sa.Column("delivered_push", sa.Integer(), nullable=False),
        sa.Column("delivered_email", sa.Integer(), nullable=False),
        sa.Column("failed_count", sa.Integer(), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_broadcasts_status_created", "admin_broadcasts", ["status", "created_at"])
    op.create_index("ix_admin_broadcasts_kind_created", "admin_broadcasts", ["kind", "created_at"])

    op.create_table(
        "admin_broadcast_deliveries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("broadcast_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("channel", sa.String(length=16), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(["broadcast_id"], ["admin_broadcasts.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "broadcast_id", "user_id", "channel",
            name="uq_admin_broadcast_delivery_target",
        ),
    )
    op.create_index(
        "ix_admin_broadcast_deliveries_broadcast",
        "admin_broadcast_deliveries",
        ["broadcast_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_admin_broadcast_deliveries_broadcast", table_name="admin_broadcast_deliveries")
    op.drop_table("admin_broadcast_deliveries")
    op.drop_index("ix_admin_broadcasts_kind_created", table_name="admin_broadcasts")
    op.drop_index("ix_admin_broadcasts_status_created", table_name="admin_broadcasts")
    op.drop_table("admin_broadcasts")
    op.drop_index("ix_admin_email_logs_kind_status", table_name="admin_email_logs")
    op.drop_index("ix_admin_email_logs_recipient_created", table_name="admin_email_logs")
    op.drop_index("ix_admin_email_logs_created", table_name="admin_email_logs")
    op.drop_table("admin_email_logs")
    op.drop_table("admin_email_templates")
    op.drop_index("ix_admin_storage_runs_status_created", table_name="admin_storage_runs")
    op.drop_index("ix_admin_storage_runs_kind_created", table_name="admin_storage_runs")
    op.drop_table("admin_storage_runs")
