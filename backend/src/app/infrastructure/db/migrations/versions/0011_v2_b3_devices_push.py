"""Add V2 B3 devices, Watch LIVE switch, and notification preferences."""

from alembic import op
import sqlalchemy as sa

revision = "0011_v2_b3_devices_push"
down_revision = "0010_v2_d1_admin_users"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "watches",
        sa.Column(
            "notify_on_live",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "watches",
        sa.Column("live_session_id", sa.Uuid(), nullable=True),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "creator_live",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "recording_expiring",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "free_minutes_low",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "notification_preferences",
        sa.Column(
            "marketing",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    op.create_table(
        "device_registrations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("device_id", sa.String(length=160), nullable=False),
        sa.Column("platform", sa.String(length=16), nullable=False),
        sa.Column("push_token", sa.String(length=4096), nullable=True),
        sa.Column("device_name", sa.String(length=160), nullable=False),
        sa.Column("app_version", sa.String(length=64), nullable=False),
        sa.Column(
            "locale",
            sa.String(length=16),
            nullable=False,
            server_default="en",
        ),
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
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["auth_sessions.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "user_id",
            "device_id",
            name="uq_device_registrations_user_device",
        ),
    )
    op.create_index(
        "ix_device_registrations_session",
        "device_registrations",
        ["session_id"],
        unique=False,
    )
    op.create_index(
        "ix_device_registrations_user",
        "device_registrations",
        ["user_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_device_registrations_user",
        table_name="device_registrations",
    )
    op.drop_index(
        "ix_device_registrations_session",
        table_name="device_registrations",
    )
    op.drop_table("device_registrations")
    op.drop_column("notification_preferences", "marketing")
    op.drop_column("notification_preferences", "free_minutes_low")
    op.drop_column("notification_preferences", "recording_expiring")
    op.drop_column("notification_preferences", "creator_live")
    op.drop_column("watches", "live_session_id")
    op.drop_column("watches", "notify_on_live")
