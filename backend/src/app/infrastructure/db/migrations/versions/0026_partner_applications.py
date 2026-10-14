"""Partner Program applications with their consent record.

Revision ID: 0026_partner_applications
Revises: 0025_creator_avatar_cache
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0026_partner_applications"
down_revision = "0025_creator_avatar_cache"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "partner_applications",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("tiktok_handle", sa.String(length=64), nullable=False),
        sa.Column("other_channel_url", sa.String(length=2048), nullable=True),
        sa.Column("niche", sa.String(length=64), nullable=False),
        sa.Column("story", sa.Text(), nullable=False),
        sa.Column("photo_key", sa.String(length=256), nullable=True),
        sa.Column("photo_content_type", sa.String(length=64), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="pending"),
        sa.Column("consent_owns_account", sa.Boolean(), nullable=False),
        sa.Column("consent_display", sa.Boolean(), nullable=False),
        sa.Column("consent_texts", sa.JSON(), nullable=False),
        sa.Column("terms_version", sa.String(length=32), nullable=False),
        sa.Column("privacy_version", sa.String(length=32), nullable=False),
        sa.Column("consent_ip", sa.String(length=64), nullable=True),
        sa.Column("consent_user_agent", sa.String(length=512), nullable=True),
        sa.Column("consent_withdrawn_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "reviewed_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index(
        "ix_partner_applications_status_created",
        "partner_applications",
        ["status", "created_at"],
    )
    op.create_index("ix_partner_applications_email", "partner_applications", ["email"])


def downgrade() -> None:
    op.drop_index("ix_partner_applications_email", table_name="partner_applications")
    op.drop_index("ix_partner_applications_status_created", table_name="partner_applications")
    op.drop_table("partner_applications")
