"""Email switches for notification emails.

Revision ID: 0030_notification_emails
Revises: 0029_watch_owner_attested
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0030_notification_emails"
down_revision = "0029_watch_owner_attested"
branch_labels = None
depends_on = None

COLUMNS = (
    "email_creator_live",
    "email_recording_ready",
    "email_recording_failed",
    "email_recording_expiring",
    "email_credits_low",
    "email_credits_exhausted",
)


def upgrade() -> None:
    for column in COLUMNS:
        op.add_column(
            "notification_preferences",
            sa.Column(column, sa.Boolean(), nullable=False, server_default=sa.true()),
        )


def downgrade() -> None:
    for column in reversed(COLUMNS):
        op.drop_column("notification_preferences", column)
