"""Rewarded ads that add cloud recording minutes (Android v2).

reward_intents gains the device the ad was watched on (per-device daily
cap and multi-account checks), the AdMob ad unit, and the credits granted.

Revision ID: 0034_rewarded_cloud_minutes
Revises: 0033_play_billing
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op

revision = "0034_rewarded_cloud_minutes"
down_revision = "0033_play_billing"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("reward_intents", sa.Column("device_id", sa.String(128), nullable=True))
    op.add_column("reward_intents", sa.Column("ad_unit", sa.String(128), nullable=True))
    op.add_column("reward_intents", sa.Column("credits_granted", sa.Integer(), nullable=True))
    op.create_index(
        "ix_reward_intents_device_verified", "reward_intents", ["device_id", "verified_at"]
    )


def downgrade() -> None:
    op.drop_index("ix_reward_intents_device_verified", table_name="reward_intents")
    op.drop_column("reward_intents", "credits_granted")
    op.drop_column("reward_intents", "ad_unit")
    op.drop_column("reward_intents", "device_id")
