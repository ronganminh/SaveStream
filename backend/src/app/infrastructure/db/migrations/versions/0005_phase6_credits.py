"""Add Phase 6 pricing, credit ledger and reservations."""

from alembic import op
import sqlalchemy as sa

revision = "0005_phase6_credits"
down_revision = "0004_phase5_watches"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "pricing_rules",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.String(length=80), nullable=False),
        sa.Column("credit_unit", sa.String(length=24), nullable=False),
        sa.Column("policy_type", sa.String(length=80), nullable=False),
        sa.Column("policy", sa.JSON(), nullable=False),
        sa.Column("public_rules", sa.JSON(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column(
            "effective_from",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_pricing_rules")),
        sa.UniqueConstraint("version", name="uq_pricing_rules_version"),
    )
    op.create_index(
        "ix_pricing_rules_active",
        "pricing_rules",
        ["is_active", "effective_from"],
        unique=False,
    )

    op.create_table(
        "pricing_snapshots",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("pricing_rule_id", sa.Uuid(), nullable=False),
        sa.Column("version", sa.String(length=80), nullable=False),
        sa.Column("credit_unit", sa.String(length=24), nullable=False),
        sa.Column("policy_type", sa.String(length=80), nullable=False),
        sa.Column("policy", sa.JSON(), nullable=False),
        sa.Column("public_rules", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["pricing_rule_id"],
            ["pricing_rules.id"],
            name=op.f("fk_pricing_snapshots_pricing_rule_id_pricing_rules"),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_pricing_snapshots")),
    )

    op.create_table(
        "credit_accounts",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("posted_balance", sa.Integer(), nullable=False),
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
        sa.CheckConstraint(
            "posted_balance >= 0",
            name=op.f("ck_credit_accounts_posted_balance_nonnegative"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_credit_accounts_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_credit_accounts")),
        sa.UniqueConstraint("user_id", name="uq_credit_accounts_user_id"),
    )

    op.create_table(
        "credit_ledger_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("entry_type", sa.String(length=24), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("balance_after", sa.Integer(), nullable=False),
        sa.Column("reference_type", sa.String(length=80), nullable=False),
        sa.Column("reference_id", sa.String(length=160), nullable=True),
        sa.Column("reference_key", sa.String(length=255), nullable=False),
        sa.Column("metadata", sa.JSON(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "balance_after >= 0",
            name=op.f("ck_credit_ledger_entries_ledger_balance_after_nonnegative"),
        ),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["credit_accounts.id"],
            name=op.f("fk_credit_ledger_entries_account_id_credit_accounts"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_credit_ledger_entries_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_credit_ledger_entries")),
        sa.UniqueConstraint(
            "reference_key",
            name="uq_credit_ledger_reference_key",
        ),
    )
    op.create_index(
        "ix_credit_ledger_user_created",
        "credit_ledger_entries",
        ["user_id", "created_at"],
        unique=False,
    )

    op.create_table(
        "credit_reservations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("account_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("recording_id", sa.Uuid(), nullable=False),
        sa.Column("pricing_snapshot_id", sa.Uuid(), nullable=False),
        sa.Column("reserved", sa.Integer(), nullable=False),
        sa.Column("settled", sa.Integer(), nullable=False),
        sa.Column("released", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
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
        sa.CheckConstraint(
            "reserved >= 0",
            name=op.f("ck_credit_reservations_reservation_reserved_nonnegative"),
        ),
        sa.CheckConstraint(
            "settled >= 0",
            name=op.f("ck_credit_reservations_reservation_settled_nonnegative"),
        ),
        sa.CheckConstraint(
            "released >= 0",
            name=op.f("ck_credit_reservations_reservation_released_nonnegative"),
        ),
        sa.CheckConstraint(
            "settled + released <= reserved",
            name=op.f("ck_credit_reservations_reservation_not_overconsumed"),
        ),
        sa.ForeignKeyConstraint(
            ["account_id"],
            ["credit_accounts.id"],
            name=op.f("fk_credit_reservations_account_id_credit_accounts"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["pricing_snapshot_id"],
            ["pricing_snapshots.id"],
            name=op.f("fk_credit_reservations_pricing_snapshot_id_pricing_snapshots"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["recording_id"],
            ["recordings.id"],
            name=op.f("fk_credit_reservations_recording_id_recordings"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_credit_reservations_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_credit_reservations")),
        sa.UniqueConstraint(
            "recording_id",
            name="uq_credit_reservations_recording_id",
        ),
    )
    op.create_index(
        "ix_credit_reservations_user_created",
        "credit_reservations",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_credit_reservations_account_status",
        "credit_reservations",
        ["account_id", "status"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        "ix_credit_reservations_account_status",
        table_name="credit_reservations",
    )
    op.drop_index(
        "ix_credit_reservations_user_created",
        table_name="credit_reservations",
    )
    op.drop_table("credit_reservations")
    op.drop_index(
        "ix_credit_ledger_user_created",
        table_name="credit_ledger_entries",
    )
    op.drop_table("credit_ledger_entries")
    op.drop_table("credit_accounts")
    op.drop_table("pricing_snapshots")
    op.drop_index("ix_pricing_rules_active", table_name="pricing_rules")
    op.drop_table("pricing_rules")
