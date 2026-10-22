"""Stop storing the device name (manufacturer/model) on device registrations.

The Android app no longer sends it. device_registrations.device_name becomes
nullable and existing values are cleared. Nothing reads it: push delivery and
admin views use the device id, push token and platform only.

Downgrade restores NOT NULL by filling cleared rows with an empty string; the
cleared names themselves are not restored (the UPDATE is one-way).

Revision ID: 0036_device_name_optional
Revises: 0035_credits_api_gaps
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0036_device_name_optional"
down_revision = "0035_credits_api_gaps"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("device_registrations") as batch:
        batch.alter_column(
            "device_name", existing_type=sa.String(length=160), nullable=True
        )
    op.execute("UPDATE device_registrations SET device_name = NULL")


def downgrade() -> None:
    op.execute("UPDATE device_registrations SET device_name = '' WHERE device_name IS NULL")
    with op.batch_alter_table("device_registrations") as batch:
        batch.alter_column(
            "device_name", existing_type=sa.String(length=160), nullable=False
        )
