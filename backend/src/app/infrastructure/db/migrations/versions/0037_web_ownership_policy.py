"""Per-client channel ownership: web attestation, web-only channels.

Adds watches.added_via and watches.ownership_basis, and the
channel_ownership_attestations table (consent evidence: statement version,
client, IP, user agent, time).

Backfill (existing channels have no creation client on record): added_via is
the client of the user's most recent sign-in session created before the
channel was added. Unverified channels added on the web are grandfathered:
"web_attested" when the old optional ownership box was ticked, otherwise
"web_attested_legacy". Nothing changes for recording until
SAVESTREAM_WEB_REQUIRE_OWNERSHIP is turned off; the Android app stops seeing
those web-only channels right away.

Revision ID: 0037_web_ownership_policy
Revises: 0036_device_name_optional
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0037_web_ownership_policy"
down_revision = "0036_device_name_optional"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("watches", sa.Column("added_via", sa.String(length=16), nullable=True))
    op.add_column("watches", sa.Column("ownership_basis", sa.String(length=24), nullable=True))
    op.create_table(
        "channel_ownership_attestations",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "watch_id",
            sa.Uuid(),
            sa.ForeignKey("watches.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("statement_version", sa.String(length=32), nullable=False),
        sa.Column("client_type", sa.String(length=16), nullable=False),
        sa.Column("ip_address", sa.String(length=64), nullable=True),
        sa.Column("user_agent", sa.String(length=512), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )
    op.create_index(
        "ix_channel_ownership_attestations_watch",
        "channel_ownership_attestations",
        ["watch_id", "created_at"],
    )
    op.execute(
        """
        UPDATE watches SET added_via = (
            SELECT s.client_type FROM auth_sessions s
            WHERE s.user_id = watches.user_id AND s.created_at <= watches.created_at
            ORDER BY s.created_at DESC LIMIT 1
        )
        """
    )
    op.execute(
        """
        UPDATE watches SET ownership_basis = CASE
            WHEN owner_attested_at IS NOT NULL THEN 'web_attested'
            ELSE 'web_attested_legacy' END
        WHERE added_via = 'web' AND owner_verified_at IS NULL
        """
    )


def downgrade() -> None:
    op.drop_index(
        "ix_channel_ownership_attestations_watch", table_name="channel_ownership_attestations"
    )
    op.drop_table("channel_ownership_attestations")
    op.drop_column("watches", "ownership_basis")
    op.drop_column("watches", "added_via")
