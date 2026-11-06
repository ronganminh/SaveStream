"""Per-account channel block (report / takedown).

Revision ID: 0038_channel_account_blocks
Revises: 0037_web_ownership_policy
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0038_channel_account_blocks"
down_revision = "0037_web_ownership_policy"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("watches", sa.Column("blocked_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "channel_account_blocks",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id", sa.Uuid(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("username", sa.String(length=128), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column(
            "complaint_id",
            sa.Uuid(),
            sa.ForeignKey("admin_complaint_cases.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "blocked_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("unblocked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "unblocked_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("unblock_reason", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("user_id", "username", name="uq_channel_account_blocks_user_username"),
    )


def downgrade() -> None:
    op.drop_table("channel_account_blocks")
    op.drop_column("watches", "blocked_at")
