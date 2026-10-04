"""Add V2 D5 packages, promotions, and bulk grants."""

import sqlalchemy as sa
from alembic import op

revision = "0014_v2_d5_packages_promotions"
down_revision = "0013_v2_b5_store_purchases"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("credit_packages") as batch_op:
        batch_op.add_column(
            sa.Column("web_variant_id", sa.String(length=160), nullable=True)
        )
        batch_op.add_column(
            sa.Column(
                "display_order",
                sa.Integer(),
                nullable=False,
                server_default="0",
            )
        )
        batch_op.create_unique_constraint(
            "uq_credit_packages_web_variant_id",
            ["web_variant_id"],
        )

    op.create_table(
        "promotion_codes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=64), nullable=False),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("max_redemptions", sa.Integer(), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "counts_as_purchase",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column("created_by_user_id", sa.Uuid(), nullable=True),
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
        sa.CheckConstraint("credits > 0", name="promotion_credits_positive"),
        sa.CheckConstraint(
            "max_redemptions IS NULL OR max_redemptions > 0",
            name="promotion_max_redemptions_positive",
        ),
        sa.ForeignKeyConstraint(
            ["created_by_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code", name="uq_promotion_codes_code"),
    )
    op.create_index(
        "ix_promotion_codes_active_expires",
        "promotion_codes",
        ["active", "expires_at"],
    )

    op.create_table(
        "promotion_redemptions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("promotion_code_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("ledger_entry_id", sa.Uuid(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["promotion_code_id"],
            ["promotion_codes.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["ledger_entry_id"],
            ["credit_ledger_entries.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "promotion_code_id",
            "user_id",
            name="uq_promotion_redemptions_code_user",
        ),
    )
    op.create_index(
        "ix_promotion_redemptions_code_created",
        "promotion_redemptions",
        ["promotion_code_id", "created_at"],
    )
    op.create_index(
        "ix_promotion_redemptions_user_created",
        "promotion_redemptions",
        ["user_id", "created_at"],
    )

    op.create_table(
        "admin_bulk_grants",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column(
            "counts_as_purchase",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column("reason", sa.Text(), nullable=False),
        sa.Column("filters", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="queued"),
        sa.Column("audience_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("total_credits", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("delivered_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("failed_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.CheckConstraint("credits > 0", name="bulk_grant_credits_positive"),
        sa.ForeignKeyConstraint(
            ["actor_user_id"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_admin_bulk_grants_status_created",
        "admin_bulk_grants",
        ["status", "created_at"],
    )

    op.create_table(
        "admin_bulk_grant_deliveries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("bulk_grant_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("ledger_entry_id", sa.Uuid(), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="queued"),
        sa.Column("error", sa.Text(), nullable=True),
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
            ["bulk_grant_id"],
            ["admin_bulk_grants.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["ledger_entry_id"],
            ["credit_ledger_entries.id"],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "bulk_grant_id",
            "user_id",
            name="uq_admin_bulk_grant_deliveries_grant_user",
        ),
    )
    op.create_index(
        "ix_admin_bulk_grant_deliveries_grant_status",
        "admin_bulk_grant_deliveries",
        ["bulk_grant_id", "status"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_admin_bulk_grant_deliveries_grant_status",
        table_name="admin_bulk_grant_deliveries",
    )
    op.drop_table("admin_bulk_grant_deliveries")
    op.drop_index(
        "ix_admin_bulk_grants_status_created",
        table_name="admin_bulk_grants",
    )
    op.drop_table("admin_bulk_grants")
    op.drop_index(
        "ix_promotion_redemptions_user_created",
        table_name="promotion_redemptions",
    )
    op.drop_index(
        "ix_promotion_redemptions_code_created",
        table_name="promotion_redemptions",
    )
    op.drop_table("promotion_redemptions")
    op.drop_index(
        "ix_promotion_codes_active_expires",
        table_name="promotion_codes",
    )
    op.drop_table("promotion_codes")
    with op.batch_alter_table("credit_packages") as batch_op:
        batch_op.drop_constraint(
            "uq_credit_packages_web_variant_id",
            type_="unique",
        )
        batch_op.drop_column("display_order")
        batch_op.drop_column("web_variant_id")
