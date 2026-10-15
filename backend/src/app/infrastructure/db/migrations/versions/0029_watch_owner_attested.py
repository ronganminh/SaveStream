"""Optional ownership/permission confirmation when a channel is added.

Revision ID: 0029_watch_owner_attested
Revises: 0028_consent_aup
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0029_watch_owner_attested"
down_revision = "0028_consent_aup"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "watches", sa.Column("owner_attested_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("watches", "owner_attested_at")
