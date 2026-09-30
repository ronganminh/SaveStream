"""Add Phase 9 privacy deletion completion timestamp."""

from alembic import op
import sqlalchemy as sa

revision = "0007_phase9_privacy"
down_revision = "0006_phase7_billing"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("deletion_completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_users_deletion_due",
        "users",
        ["deletion_requested_at", "deletion_completed_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_users_deletion_due", table_name="users")
    op.drop_column("users", "deletion_completed_at")
