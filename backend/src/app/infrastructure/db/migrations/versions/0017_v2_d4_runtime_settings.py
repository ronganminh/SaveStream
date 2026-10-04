"""Add D4 runtime settings.

Revision ID: 0017_v2_d4_runtime_settings
Revises: 0016_v2_d3_recording_retention
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0017_v2_d4_runtime_settings"
down_revision = "0016_v2_d3_recording_retention"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_runtime_settings",
        sa.Column("key", sa.String(length=96), nullable=False),
        sa.Column("value", sa.JSON(), nullable=False),
        sa.Column("updated_by_user_id", sa.Uuid(), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["updated_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("key"),
    )


def downgrade() -> None:
    op.drop_table("admin_runtime_settings")
