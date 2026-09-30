"""Add Phase 7 billing and payment tables."""

from alembic import op
import sqlalchemy as sa

revision = "0006_phase7_billing"
down_revision = "0005_phase6_credits"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "credit_packages",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(length=80), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
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
        sa.CheckConstraint("credits > 0", name="ck_credit_packages_credits_positive"),
        sa.CheckConstraint(
            "amount_minor >= 0",
            name="ck_credit_packages_amount_minor_nonnegative",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_credit_packages")),
        sa.UniqueConstraint("code", name="uq_credit_packages_code"),
    )
    op.create_index(
        "ix_credit_packages_active",
        "credit_packages",
        ["active", "created_at"],
        unique=False,
    )

    op.create_table(
        "payment_orders",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("package_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("provider", sa.String(length=80), nullable=True),
        sa.Column("provider_reference", sa.String(length=255), nullable=True),
        sa.Column("checkout_url", sa.String(length=2048), nullable=True),
        sa.Column("return_url", sa.String(length=2048), nullable=True),
        sa.Column("refunded_credits", sa.Integer(), nullable=False),
        sa.Column("refunded_amount_minor", sa.Integer(), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failure_code", sa.String(length=120), nullable=True),
        sa.Column("failure_message", sa.Text(), nullable=True),
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
            "credits > 0",
            name="ck_payment_orders_payment_order_credits_positive",
        ),
        sa.CheckConstraint(
            "amount_minor >= 0",
            name="ck_payment_orders_payment_order_amount_nonnegative",
        ),
        sa.CheckConstraint(
            "refunded_credits >= 0",
            name="ck_payment_orders_refunded_credits_nonnegative",
        ),
        sa.CheckConstraint(
            "refunded_amount_minor >= 0",
            name="ck_payment_orders_refunded_amount_nonnegative",
        ),
        sa.CheckConstraint(
            "refunded_credits <= credits",
            name="ck_payment_orders_refund_credits_not_over_order",
        ),
        sa.CheckConstraint(
            "refunded_amount_minor <= amount_minor",
            name="ck_payment_orders_refund_amount_not_over_order",
        ),
        sa.ForeignKeyConstraint(
            ["package_id"],
            ["credit_packages.id"],
            name=op.f("fk_payment_orders_package_id_credit_packages"),
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_payment_orders_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_payment_orders")),
        sa.UniqueConstraint(
            "provider",
            "provider_reference",
            name="uq_payment_orders_provider_reference",
        ),
    )
    op.create_index(
        "ix_payment_orders_user_created",
        "payment_orders",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_payment_orders_status_updated",
        "payment_orders",
        ["status", "updated_at"],
        unique=False,
    )

    op.create_table(
        "payment_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("payment_order_id", sa.Uuid(), nullable=True),
        sa.Column("provider", sa.String(length=80), nullable=False),
        sa.Column("provider_event_id", sa.String(length=255), nullable=False),
        sa.Column("event_type", sa.String(length=80), nullable=False),
        sa.Column("provider_reference", sa.String(length=255), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("signature_verified", sa.Boolean(), nullable=False),
        sa.Column("processing_error", sa.Text(), nullable=True),
        sa.Column(
            "received_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(
            ["payment_order_id"],
            ["payment_orders.id"],
            name=op.f("fk_payment_events_payment_order_id_payment_orders"),
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_payment_events")),
        sa.UniqueConstraint(
            "provider",
            "provider_event_id",
            name="uq_payment_events_provider_event",
        ),
    )
    op.create_index(
        "ix_payment_events_unprocessed",
        "payment_events",
        ["processed_at", "received_at"],
        unique=False,
    )

    op.create_table(
        "refunds",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("payment_order_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("request_key", sa.String(length=255), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("credits", sa.Integer(), nullable=False),
        sa.Column("amount_minor", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(length=80), nullable=True),
        sa.Column("provider_refund_reference", sa.String(length=255), nullable=True),
        sa.Column("failure_message", sa.Text(), nullable=True),
        sa.Column("succeeded_at", sa.DateTime(timezone=True), nullable=True),
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
        sa.CheckConstraint("credits > 0", name="ck_refunds_refund_credits_positive"),
        sa.CheckConstraint(
            "amount_minor > 0",
            name="ck_refunds_refund_amount_positive",
        ),
        sa.ForeignKeyConstraint(
            ["payment_order_id"],
            ["payment_orders.id"],
            name=op.f("fk_refunds_payment_order_id_payment_orders"),
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name=op.f("fk_refunds_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_refunds")),
        sa.UniqueConstraint("request_key", name="uq_refunds_request_key"),
        sa.UniqueConstraint(
            "provider",
            "provider_refund_reference",
            name="uq_refunds_provider_reference",
        ),
    )
    op.create_index(
        "ix_refunds_order_created",
        "refunds",
        ["payment_order_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_refunds_order_created", table_name="refunds")
    op.drop_table("refunds")
    op.drop_index("ix_payment_events_unprocessed", table_name="payment_events")
    op.drop_table("payment_events")
    op.drop_index("ix_payment_orders_status_updated", table_name="payment_orders")
    op.drop_index("ix_payment_orders_user_created", table_name="payment_orders")
    op.drop_table("payment_orders")
    op.drop_index("ix_credit_packages_active", table_name="credit_packages")
    op.drop_table("credit_packages")
