"""Video downloader: takedown reports and the blocklist.

Revision ID: 0040_video_downloader_blocklist
Revises: 0039_verification_first_check
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0040_video_downloader_blocklist"
down_revision = "0039_verification_first_check"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "video_download_reports",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("reference", sa.String(length=16), nullable=False, unique=True),
        sa.Column("video_id", sa.String(length=32), nullable=False),
        sa.Column("video_url", sa.String(length=2048), nullable=False),
        sa.Column("reporter_name", sa.String(length=200), nullable=False),
        sa.Column("reporter_email", sa.String(length=320), nullable=False),
        sa.Column("relationship", sa.String(length=24), nullable=False),
        sa.Column("reason", sa.String(length=24), nullable=False),
        sa.Column("details", sa.Text(), nullable=False, server_default=""),
        sa.Column(
            "complaint_id",
            sa.Uuid(),
            sa.ForeignKey("admin_complaint_cases.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
    )
    op.create_index("ix_video_download_reports_created", "video_download_reports", ["created_at"])
    op.create_index("ix_video_download_reports_video", "video_download_reports", ["video_id"])
    op.create_table(
        "video_download_blocklist",
        sa.Column("video_id", sa.String(length=32), primary_key=True),
        sa.Column("video_url", sa.String(length=2048), nullable=False),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("source", sa.String(length=16), nullable=False),
        sa.Column(
            "report_id",
            sa.Uuid(),
            sa.ForeignKey("video_download_reports.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "blocked_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "blocked_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("unblocked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "unblocked_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("unblock_reason", sa.Text(), nullable=True),
    )
    op.create_index(
        "ix_video_download_blocklist_active",
        "video_download_blocklist",
        ["unblocked_at", "blocked_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_video_download_blocklist_active", table_name="video_download_blocklist")
    op.drop_table("video_download_blocklist")
    op.drop_index("ix_video_download_reports_video", table_name="video_download_reports")
    op.drop_index("ix_video_download_reports_created", table_name="video_download_reports")
    op.drop_table("video_download_reports")
