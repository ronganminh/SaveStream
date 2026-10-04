"""Add V2 B5 store product identifiers to credit packages."""

import uuid

import sqlalchemy as sa
from alembic import op

revision = "0013_v2_b5_store_purchases"
down_revision = "0012_v2_d7_admin_operations"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("credit_packages") as batch_op:
        batch_op.add_column(
            sa.Column(
                "app_store_product_id",
                sa.String(length=160),
                nullable=True,
            )
        )
        batch_op.add_column(
            sa.Column(
                "google_play_product_id",
                sa.String(length=160),
                nullable=True,
            )
        )
        batch_op.create_unique_constraint(
            "uq_credit_packages_app_store_product_id",
            ["app_store_product_id"],
        )
        batch_op.create_unique_constraint(
            "uq_credit_packages_google_play_product_id",
            ["google_play_product_id"],
        )

    catalog = (
        ("starter", "Starter", 3000, 999, "savestream.hours.50"),
        ("standard", "Standard", 9000, 2499, "savestream.hours.150"),
        ("premium", "Premium", 24000, 5999, "savestream.hours.400"),
    )
    packages = sa.table(
        "credit_packages",
        sa.column("id", sa.Uuid()),
        sa.column("code", sa.String()),
        sa.column("name", sa.String()),
        sa.column("credits", sa.Integer()),
        sa.column("amount_minor", sa.Integer()),
        sa.column("currency", sa.String()),
        sa.column("app_store_product_id", sa.String()),
        sa.column("google_play_product_id", sa.String()),
        sa.column("active", sa.Boolean()),
    )
    bind = op.get_bind()
    for code, name, credits, amount_minor, product_id in catalog:
        existing = bind.execute(
            sa.select(packages.c.code).where(packages.c.code == code)
        ).first()
        values = {
            "name": name,
            "credits": credits,
            "amount_minor": amount_minor,
            "currency": "USD",
            "app_store_product_id": product_id,
            "google_play_product_id": product_id,
            "active": True,
        }
        if existing is None:
            bind.execute(
                packages.insert().values(
                    id=uuid.uuid5(
                        uuid.NAMESPACE_URL,
                        f"savestream:credit-package:{code}",
                    ),
                    code=code,
                    **values,
                )
            )
        else:
            bind.execute(
                packages.update()
                .where(packages.c.code == code)
                .values(**values)
            )


def downgrade() -> None:
    with op.batch_alter_table("credit_packages") as batch_op:
        batch_op.drop_constraint(
            "uq_credit_packages_google_play_product_id",
            type_="unique",
        )
        batch_op.drop_constraint(
            "uq_credit_packages_app_store_product_id",
            type_="unique",
        )
        batch_op.drop_column("google_play_product_id")
        batch_op.drop_column("app_store_product_id")
