"""Acceptable Use Policy confirmation on legal consent records.

Revision ID: 0028_consent_aup
Revises: 0027_artifact_thumbnails
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0028_consent_aup"
down_revision = "0027_artifact_thumbnails"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("legal_consents", sa.Column("aup_accepted", sa.Boolean(), nullable=True))
    op.add_column("legal_consents", sa.Column("aup_version", sa.String(length=32), nullable=True))


def downgrade() -> None:
    op.drop_column("legal_consents", "aup_version")
    op.drop_column("legal_consents", "aup_accepted")
