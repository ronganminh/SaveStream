"""Record Terms/Privacy acceptance (version, time, IP) per user.

Revision ID: 0023_legal_consents
Revises: 0022_invalid_watch_sources
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0023_legal_consents"
down_revision = "0022_invalid_watch_sources"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "legal_consents",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("terms_version", sa.String(length=32), nullable=False),
        sa.Column("privacy_version", sa.String(length=32), nullable=False),
        sa.Column("age_confirmed", sa.Boolean(), nullable=False),
        sa.Column("method", sa.String(length=32), nullable=False),
        sa.Column("ip_address", sa.String(length=64), nullable=False),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column(
            "accepted_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index("ix_legal_consents_user_id", "legal_consents", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_legal_consents_user_id", table_name="legal_consents")
    op.drop_table("legal_consents")
