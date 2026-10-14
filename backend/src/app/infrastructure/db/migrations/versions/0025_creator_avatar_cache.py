"""Cache creator avatars in object storage.

TikTok's signed CDN avatar URLs expire, so a copy is stored in R2 and served
from a stable public API URL, refreshed periodically.

Revision ID: 0025_creator_avatar_cache
Revises: 0024_artifact_media_info
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0025_creator_avatar_cache"
down_revision = "0024_artifact_media_info"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("watches", sa.Column("creator_avatar_key", sa.String(length=256), nullable=True))
    op.add_column(
        "watches", sa.Column("creator_avatar_cached_url", sa.String(length=512), nullable=True)
    )
    op.add_column(
        "watches",
        sa.Column("creator_avatar_refreshed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("watches", "creator_avatar_refreshed_at")
    op.drop_column("watches", "creator_avatar_cached_url")
    op.drop_column("watches", "creator_avatar_key")
