"""Add Phase 4 recording, artifact and event tables."""

from alembic import op
import sqlalchemy as sa

revision = "0003_phase4_recordings"
down_revision = "0002_phase3_identity"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "recordings",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("source_type", sa.String(length=24), nullable=False),
        sa.Column("source_value", sa.String(length=2048), nullable=False),
        sa.Column("resolved_username", sa.String(length=160), nullable=True),
        sa.Column("room_id", sa.String(length=128), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("active_dedupe_key", sa.String(length=512), nullable=True),
        sa.Column("max_duration_seconds", sa.Integer(), nullable=True),
        sa.Column("quality", sa.String(length=24), nullable=False),
        sa.Column("container", sa.String(length=16), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column("bytes_recorded", sa.BigInteger(), nullable=False),
        sa.Column("estimated_max_cost", sa.Integer(), nullable=False),
        sa.Column("actual_cost", sa.Integer(), nullable=True),
        sa.Column("credit_reservation_id", sa.String(length=128), nullable=True),
        sa.Column("error_code", sa.String(length=80), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("error_retryable", sa.Boolean(), nullable=True),
        sa.Column("worker_lease_id", sa.Uuid(), nullable=True),
        sa.Column("worker_attempts", sa.Integer(), nullable=False),
        sa.Column("heartbeat_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cleanup_requested_at", sa.DateTime(timezone=True), nullable=True),
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
            name=op.f("fk_recordings_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_recordings")),
        sa.UniqueConstraint(
            "active_dedupe_key",
            name="uq_recordings_active_dedupe_key",
        ),
    )
    op.create_index(
        "ix_recordings_owner_created",
        "recordings",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_recordings_owner_status",
        "recordings",
        ["user_id", "status"],
        unique=False,
    )

    op.create_table(
        "artifacts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("recording_id", sa.Uuid(), nullable=False),
        sa.Column("kind", sa.String(length=32), nullable=False),
        sa.Column("container", sa.String(length=16), nullable=False),
        sa.Column("storage_key", sa.String(length=1024), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("checksum_sha256", sa.String(length=64), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["recording_id"],
            ["recordings.id"],
            name=op.f("fk_artifacts_recording_id_recordings"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_artifacts")),
        sa.UniqueConstraint("storage_key", name="uq_artifacts_storage_key"),
    )
    op.create_index(
        "ix_artifacts_recording",
        "artifacts",
        ["recording_id"],
        unique=False,
    )

    op.create_table(
        "recording_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("recording_id", sa.Uuid(), nullable=False),
        sa.Column("sequence", sa.Integer(), nullable=False),
        sa.Column("event_type", sa.String(length=120), nullable=False),
        sa.Column("data", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["recording_id"],
            ["recordings.id"],
            name=op.f("fk_recording_events_recording_id_recordings"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_recording_events")),
        sa.UniqueConstraint(
            "recording_id",
            "sequence",
            name="uq_recording_events_sequence",
        ),
    )
    op.create_index(
        "ix_recording_events_recording_sequence",
        "recording_events",
        ["recording_id", "sequence"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_recording_events_recording_sequence",
        table_name="recording_events",
    )
    op.drop_table("recording_events")
    op.drop_index("ix_artifacts_recording", table_name="artifacts")
    op.drop_table("artifacts")
    op.drop_index("ix_recordings_owner_status", table_name="recordings")
    op.drop_index("ix_recordings_owner_created", table_name="recordings")
    op.drop_table("recordings")
