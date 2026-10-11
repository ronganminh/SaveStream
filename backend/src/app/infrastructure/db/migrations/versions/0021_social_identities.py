"""Map Firebase identities to existing SaveStream users.

Revision ID: 0021_social_identities
Revises: 0020_creator_profile_metadata
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0021_social_identities"
down_revision = "0020_creator_profile_metadata"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "social_identities",
        sa.Column("firebase_uid", sa.String(length=128), primary_key=True),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_social_identities_user_id", "social_identities", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_social_identities_user_id", table_name="social_identities")
    op.drop_table("social_identities")
