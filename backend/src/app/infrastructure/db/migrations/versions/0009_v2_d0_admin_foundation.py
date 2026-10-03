"""Add Track D0 admin roles, MFA, step-up grants, and audit context."""

from alembic import op
import sqlalchemy as sa

revision = "0009_v2_d0_admin_foundation"
down_revision = "0008_phase11_notifications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "auth_sessions",
        sa.Column("admin_mfa_verified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column("audit_logs", sa.Column("actor_role", sa.String(length=32), nullable=True))
    op.add_column("audit_logs", sa.Column("reason", sa.Text(), nullable=True))
    op.add_column("audit_logs", sa.Column("before_state", sa.JSON(), nullable=True))
    op.add_column("audit_logs", sa.Column("after_state", sa.JSON(), nullable=True))

    op.create_table(
        "admin_mfa_credentials",
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("encrypted_secret", sa.Text(), nullable=False),
        sa.Column("recovery_code_hashes", sa.JSON(), nullable=False),
        sa.Column("enabled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reset_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )
    op.create_table(
        "admin_step_up_grants",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("role", sa.String(length=32), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(["session_id"], ["auth_sessions.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )
    op.create_index(
        "ix_admin_step_up_grants_user_expires",
        "admin_step_up_grants",
        ["user_id", "expires_at"],
        unique=False,
    )

    # Existing administrators become owners. The legacy "admin" role remains
    # understood by the application so tokens/sessions in flight are not broken.
    op.execute("UPDATE users SET role = 'owner' WHERE role = 'admin'")


def downgrade() -> None:
    op.execute("UPDATE users SET role = 'admin' WHERE role = 'owner'")
    op.drop_index(
        "ix_admin_step_up_grants_user_expires",
        table_name="admin_step_up_grants",
    )
    op.drop_table("admin_step_up_grants")
    op.drop_table("admin_mfa_credentials")
    op.drop_column("audit_logs", "after_state")
    op.drop_column("audit_logs", "before_state")
    op.drop_column("audit_logs", "reason")
    op.drop_column("audit_logs", "actor_role")
    op.drop_column("auth_sessions", "admin_mfa_verified_at")
