"""Persist public TikTok creator display metadata for Watches.

Revision ID: 0020_creator_profile_metadata
Revises: 0019_v2_d9_overview_reports
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0020_creator_profile_metadata"
down_revision = "0019_v2_d9_overview_reports"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("watches") as batch:
        batch.add_column(sa.Column("creator_display_name", sa.String(length=160)))
        batch.add_column(sa.Column("creator_avatar_url", sa.String(length=2048)))


def downgrade() -> None:
    with op.batch_alter_table("watches") as batch:
        batch.drop_column("creator_avatar_url")
        batch.drop_column("creator_display_name")
