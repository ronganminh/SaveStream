"""V2 B4 local recording, free-minute and reward state.

Revision ID: 0014_v2_b4_local_recordings
Revises: 0013_v2_b5_store_purchases
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0014_v2_b4_local_recordings"
down_revision = "0013_v2_b5_store_purchases"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "local_daily_usage",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("usage_day", sa.Date(), nullable=False),
        sa.Column("used_minutes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "usage_day", name="uq_local_daily_usage_user_day"),
    )
    op.create_index(
        "ix_local_daily_usage_user_day",
        "local_daily_usage",
        ["user_id", "usage_day"],
        unique=False,
    )

    op.create_table(
        "local_recording_sessions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("watch_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.String(length=160), nullable=False),
        sa.Column("device_name", sa.String(length=160), nullable=False),
        sa.Column("creator_username", sa.String(length=160), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="active"),
        sa.Column("granted_seconds", sa.Integer(), nullable=False),
        sa.Column("free_granted_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("unlimited", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("extension_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("lease_expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("recorded_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("size_bytes", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("end_reason", sa.String(length=40), nullable=True),
        sa.Column("finish_payload_hash", sa.String(length=64), nullable=True),
        sa.Column("slot_grant_id", sa.Uuid(), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["watch_id"], ["watches.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_local_sessions_user_started", "local_recording_sessions", ["user_id", "started_at"])
    op.create_index("ix_local_sessions_user_status", "local_recording_sessions", ["user_id", "status"])
    op.create_index("ix_local_sessions_lease", "local_recording_sessions", ["status", "lease_expires_at"])

    op.create_table(
        "reward_intents",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("purpose", sa.String(length=32), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="pending"),
        sa.Column("transaction_id", sa.String(length=160), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("valid_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["session_id"], ["local_recording_sessions.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("transaction_id", name="uq_reward_intents_transaction_id"),
    )
    op.create_index("ix_reward_intents_user_created", "reward_intents", ["user_id", "created_at"])
    op.create_index("ix_reward_intents_user_status", "reward_intents", ["user_id", "status"])

    op.create_table(
        "reward_user_states",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("invalid_streak", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("locked_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )

    op.create_table(
        "local_slot_grants",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("reward_ids", sa.JSON(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_local_slot_grants_user_expiry", "local_slot_grants", ["user_id", "expires_at"])


def downgrade() -> None:
    op.drop_index("ix_local_slot_grants_user_expiry", table_name="local_slot_grants")
    op.drop_table("local_slot_grants")
    op.drop_table("reward_user_states")
    op.drop_index("ix_reward_intents_user_status", table_name="reward_intents")
    op.drop_index("ix_reward_intents_user_created", table_name="reward_intents")
    op.drop_table("reward_intents")
    op.drop_index("ix_local_sessions_lease", table_name="local_recording_sessions")
    op.drop_index("ix_local_sessions_user_status", table_name="local_recording_sessions")
    op.drop_index("ix_local_sessions_user_started", table_name="local_recording_sessions")
    op.drop_table("local_recording_sessions")
    op.drop_index("ix_local_daily_usage_user_day", table_name="local_daily_usage")
    op.drop_table("local_daily_usage")
