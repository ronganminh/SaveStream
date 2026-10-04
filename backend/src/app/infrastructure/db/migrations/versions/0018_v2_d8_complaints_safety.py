"""Add D8 complaints and creator blocks.

Revision ID: 0018_v2_d8_complaints_safety
Revises: 0017_v2_d4_runtime_settings
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0018_v2_d8_complaints_safety"
down_revision = "0017_v2_d4_runtime_settings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_complaint_cases",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(length=24), nullable=False),
        sa.Column("complainant_name", sa.String(length=200), nullable=False),
        sa.Column("complainant_email", sa.String(length=320), nullable=False),
        sa.Column("channel_source_type", sa.String(length=24), nullable=True),
        sa.Column("channel_source_value", sa.String(length=2048), nullable=True),
        sa.Column("recording_id", sa.Uuid(), nullable=True),
        sa.Column("summary", sa.String(length=240), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("assigned_to_user_id", sa.Uuid(), nullable=True),
        sa.Column("created_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["recording_id"], ["recordings.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["assigned_to_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_complaints_status_created", "admin_complaint_cases", ["status", "created_at"])
    op.create_index("ix_admin_complaints_assignee_status", "admin_complaint_cases", ["assigned_to_user_id", "status"])
    op.create_index("ix_admin_complaints_recording", "admin_complaint_cases", ["recording_id"])

    op.create_table(
        "admin_complaint_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("complaint_id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("action", sa.String(length=48), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("metadata", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["complaint_id"], ["admin_complaint_cases.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_admin_complaint_events_case_created", "admin_complaint_events", ["complaint_id", "created_at"])

    op.create_table(
        "admin_creator_blocks",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(length=24), nullable=False),
        sa.Column("source_value", sa.String(length=2048), nullable=False),
        sa.Column("complaint_id", sa.Uuid(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("blocked_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("unblocked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("unblocked_by_user_id", sa.Uuid(), nullable=True),
        sa.Column("unblock_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["complaint_id"], ["admin_complaint_cases.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["blocked_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["unblocked_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("source_type", "source_value", name="uq_admin_creator_blocks_source"),
    )
    op.create_index("ix_admin_creator_blocks_active", "admin_creator_blocks", ["unblocked_at", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_admin_creator_blocks_active", table_name="admin_creator_blocks")
    op.drop_table("admin_creator_blocks")
    op.drop_index("ix_admin_complaint_events_case_created", table_name="admin_complaint_events")
    op.drop_table("admin_complaint_events")
    op.drop_index("ix_admin_complaints_recording", table_name="admin_complaint_cases")
    op.drop_index("ix_admin_complaints_assignee_status", table_name="admin_complaint_cases")
    op.drop_index("ix_admin_complaints_status_created", table_name="admin_complaint_cases")
    op.drop_table("admin_complaint_cases")
