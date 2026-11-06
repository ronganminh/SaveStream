"""Remember when a channel verification code was first checked.

The "still checking" answer covers the first minutes after the first check,
while TikTok may still be showing the old bio.

Revision ID: 0037_verification_first_check
Revises: 0036_device_name_optional
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0037_verification_first_check"
down_revision = "0036_device_name_optional"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "channel_verifications",
        sa.Column("first_checked_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    with op.batch_alter_table("channel_verifications") as batch:
        batch.drop_column("first_checked_at")
