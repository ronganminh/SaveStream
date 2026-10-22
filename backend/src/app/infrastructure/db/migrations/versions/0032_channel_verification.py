"""Channel ownership verification (one-time code in the TikTok bio).

Channels that already exist get 14 days to verify before recording stops;
channels added from now on must verify before their first recording.

Revision ID: 0032_channel_verification
Revises: 0031_account_status
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import sqlalchemy as sa
from alembic import op

revision = "0032_channel_verification"
down_revision = "0031_account_status"
branch_labels = None
depends_on = None

GRACE_DAYS = 14


def upgrade() -> None:
    op.add_column("watches", sa.Column("owner_verified_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("watches", sa.Column("owner_verified_tiktok_id", sa.String(64), nullable=True))
    op.add_column("watches", sa.Column("verification_method", sa.String(16), nullable=True))
    op.add_column("watches", sa.Column("verification_due_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column(
        "watches",
        sa.Column("verification_reminders_sent", sa.Integer(), nullable=False, server_default="0"),
    )
    due = datetime.now(timezone.utc) + timedelta(days=GRACE_DAYS)
    op.execute(
        sa.text(
            "UPDATE watches SET verification_due_at = :due WHERE verification_due_at IS NULL"
        ).bindparams(due=due)
    )
    op.create_table(
        "channel_verifications",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("watch_id", sa.Uuid(), sa.ForeignKey("watches.id", ondelete="CASCADE"), nullable=False),
        sa.Column("username", sa.String(160), nullable=False),
        sa.Column("code", sa.String(16), nullable=False),
        sa.Column("status", sa.String(16), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("last_checked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_result", sa.String(32), nullable=True),
        sa.Column("verified_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("tiktok_user_id", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
    )
    op.create_index(
        "ix_channel_verifications_watch", "channel_verifications", ["watch_id", "created_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_channel_verifications_watch", table_name="channel_verifications")
    op.drop_table("channel_verifications")
    for column in (
        "verification_reminders_sent",
        "verification_due_at",
        "verification_method",
        "owner_verified_tiktok_id",
        "owner_verified_at",
    ):
        op.drop_column("watches", column)
