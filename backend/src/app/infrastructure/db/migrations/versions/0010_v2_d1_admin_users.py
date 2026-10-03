"""V2 D1 admin user support notes.

Revision ID: 0010_v2_d1_admin_users
Revises: 0009_v2_d0_admin_foundation
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0010_v2_d1_admin_users"
down_revision = "0009_v2_d0_admin_foundation"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "admin_user_notes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("author_user_id", sa.Uuid(), nullable=True),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["author_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_admin_user_notes_user_created",
        "admin_user_notes",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_admin_user_notes_author_created",
        "admin_user_notes",
        ["author_user_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_admin_user_notes_author_created", table_name="admin_user_notes")
    op.drop_index("ix_admin_user_notes_user_created", table_name="admin_user_notes")
    op.drop_table("admin_user_notes")
