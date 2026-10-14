"""Disable Watches whose source is not a valid TikTok handle, link or room id.

Older API/mobile clients could store arbitrary text (for example an email
address) as a Watch source; the scheduler then failed forever with
"Error extracting RoomID". The rows are kept for audit but stop polling.

Revision ID: 0022_invalid_watch_sources
Revises: 0021_social_identities
"""

from __future__ import annotations

import re

import sqlalchemy as sa
from alembic import op

revision = "0022_invalid_watch_sources"
down_revision = "0021_social_identities"
branch_labels = None
depends_on = None

_USERNAME = re.compile(r"^[A-Za-z0-9._]{2,24}$")
_PROFILE_URL = re.compile(
    r"^(?:https?://)?(?:www\.)?tiktok\.com/@([A-Za-z0-9._]{2,24})(?:[/?#].*)?$",
    re.IGNORECASE,
)
_TOKEN = re.compile(r"^[^\s@]+$")
_STREAM_URL = re.compile(r"^https?://[^\s]+$", re.IGNORECASE)


def _is_valid(source_type: str, value: str) -> bool:
    value = (value or "").strip()
    if source_type == "username":
        return bool(_USERNAME.match(value.lstrip("@")))
    if source_type == "url":
        return bool(_PROFILE_URL.match(value) or _STREAM_URL.match(value))
    if source_type == "room_id":
        return bool(_TOKEN.match(value))
    return False


def upgrade() -> None:
    watches = sa.table(
        "watches",
        sa.column("id", sa.Uuid()),
        sa.column("source_type", sa.String()),
        sa.column("source_value", sa.String()),
        sa.column("status", sa.String()),
        sa.column("next_check_at", sa.DateTime(timezone=True)),
        sa.column("scheduler_lease_id", sa.Uuid()),
        sa.column("scheduler_lease_expires_at", sa.DateTime(timezone=True)),
        sa.column("last_error", sa.String()),
        sa.column("deleted_at", sa.DateTime(timezone=True)),
    )
    connection = op.get_bind()
    rows = connection.execute(
        sa.select(watches.c.id, watches.c.source_type, watches.c.source_value).where(
            watches.c.deleted_at.is_(None),
            watches.c.status != "disabled",
        )
    ).all()
    invalid_ids = [row.id for row in rows if not _is_valid(row.source_type, row.source_value)]
    if not invalid_ids:
        return
    connection.execute(
        sa.update(watches)
        .where(watches.c.id.in_(invalid_ids))
        .values(
            status="disabled",
            next_check_at=None,
            scheduler_lease_id=None,
            scheduler_lease_expires_at=None,
            last_error="invalid_tiktok_source",
        )
    )


def downgrade() -> None:
    # Data cleanup only; disabled rows are not re-enabled automatically.
    pass
