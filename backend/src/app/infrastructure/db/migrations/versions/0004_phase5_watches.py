"""Add Phase 5 watches and room/session recording dedupe."""

from alembic import op
import sqlalchemy as sa

revision = "0004_phase5_watches"
down_revision = "0003_phase4_recordings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("recordings") as batch:
        batch.add_column(
            sa.Column("room_session_key", sa.String(length=64), nullable=True)
        )
        batch.create_unique_constraint(
            "uq_recordings_room_session_key",
            ["room_session_key"],
        )

    op.create_table(
        "watches",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(length=24), nullable=False),
        sa.Column("source_value", sa.String(length=2048), nullable=False),
        sa.Column("active_dedupe_key", sa.String(length=64), nullable=True),
        sa.Column("resolved_username", sa.String(length=160), nullable=True),
        sa.Column("resolved_room_id", sa.String(length=128), nullable=True),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("live_status", sa.String(length=16), nullable=False),
        sa.Column("auto_record", sa.Boolean(), nullable=False),
        sa.Column("last_checked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("next_check_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_live_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failure_count", sa.Integer(), nullable=False),
        sa.Column("last_error", sa.String(length=1000), nullable=True),
        sa.Column("scheduler_lease_id", sa.Uuid(), nullable=True),
        sa.Column(
            "scheduler_lease_expires_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_watches_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_watches")),
        sa.UniqueConstraint(
            "active_dedupe_key",
            name="uq_watches_active_dedupe_key",
        ),
    )
    op.create_index(
        "ix_watches_owner_created",
        "watches",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_watches_scheduler_due",
        "watches",
        ["status", "next_check_at", "deleted_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_watches_scheduler_due", table_name="watches")
    op.drop_index("ix_watches_owner_created", table_name="watches")
    op.drop_table("watches")
    with op.batch_alter_table("recordings") as batch:
        batch.drop_constraint(
            "uq_recordings_room_session_key",
            type_="unique",
        )
        batch.drop_column("room_session_key")
