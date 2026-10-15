"""Thumbnail frame for recording artifacts.

Revision ID: 0027_artifact_thumbnails
Revises: 0026_partner_applications
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0027_artifact_thumbnails"
down_revision = "0026_partner_applications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("artifacts", sa.Column("thumbnail_key", sa.String(length=1024), nullable=True))


def downgrade() -> None:
    op.drop_column("artifacts", "thumbnail_key")
