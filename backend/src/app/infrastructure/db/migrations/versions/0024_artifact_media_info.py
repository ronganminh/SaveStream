"""Store the probed media duration and frame size of each artifact.

Revision ID: 0024_artifact_media_info
Revises: 0023_legal_consents
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0024_artifact_media_info"
down_revision = "0023_legal_consents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("artifacts", sa.Column("duration_ms", sa.BigInteger(), nullable=True))
    op.add_column("artifacts", sa.Column("width", sa.Integer(), nullable=True))
    op.add_column("artifacts", sa.Column("height", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("artifacts", "height")
    op.drop_column("artifacts", "width")
    op.drop_column("artifacts", "duration_ms")
