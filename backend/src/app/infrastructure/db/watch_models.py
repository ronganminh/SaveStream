from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, Uuid, func
from sqlalchemy.orm import Mapped, mapped_column

from .models import Base


class Watch(Base):
    __tablename__ = "watches"
    __table_args__ = (
        Index("ix_watches_owner_created", "user_id", "created_at"),
        Index("ix_watches_scheduler_due", "status", "next_check_at", "deleted_at"),
        UniqueConstraint("active_dedupe_key", name="uq_watches_active_dedupe_key"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    source_type: Mapped[str] = mapped_column(String(24), nullable=False)
    source_value: Mapped[str] = mapped_column(String(2048), nullable=False)
    active_dedupe_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    resolved_username: Mapped[str | None] = mapped_column(String(160), nullable=True)
    creator_display_name: Mapped[str | None] = mapped_column(
        String(160), nullable=True
    )
    # Raw TikTok CDN URL from the profile lookup; it expires after a while.
    creator_avatar_url: Mapped[str | None] = mapped_column(
        String(2048), nullable=True
    )
    # Copy kept in object storage and served from a stable public API URL;
    # see app.application.creators.avatar_cache.
    creator_avatar_key: Mapped[str | None] = mapped_column(String(256), nullable=True)
    creator_avatar_cached_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    creator_avatar_refreshed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    resolved_room_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    status: Mapped[str] = mapped_column(String(40), nullable=False, default="active")
    live_status: Mapped[str] = mapped_column(String(16), nullable=False, default="unknown")
    auto_record: Mapped[bool] = mapped_column(nullable=False, default=True)
    notify_on_live: Mapped[bool] = mapped_column(nullable=False, default=True)
    live_session_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid(as_uuid=True), nullable=True
    )
    last_checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    next_check_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_live_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    # When the user ticked the optional ownership/permission box on Add channel.
    owner_attested_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Channel ownership: the owner put a one-time code in the TikTok bio
    # (or an admin verified it). Only verified channels may be recorded once
    # verification_due_at has passed (channels added before verification
    # existed got a grace period).
    owner_verified_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    owner_verified_tiktok_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    verification_method: Mapped[str | None] = mapped_column(String(16), nullable=True)
    verification_due_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # 1 = "verify within 14 days", 2 = "7 days left", 3 = "recording paused".
    verification_reminders_sent: Mapped[int] = mapped_column(
        Integer, nullable=False, default=0, server_default="0"
    )
    failure_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_error: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    scheduler_lease_id: Mapped[uuid.UUID | None] = mapped_column(Uuid(as_uuid=True), nullable=True)
    scheduler_lease_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class ChannelVerification(Base):
    """A one-time bio code proving the user controls a TikTok channel."""

    __tablename__ = "channel_verifications"
    __table_args__ = (Index("ix_channel_verifications_watch", "watch_id", "created_at"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    watch_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("watches.id", ondelete="CASCADE"), nullable=False
    )
    username: Mapped[str] = mapped_column(String(160), nullable=False)
    code: Mapped[str] = mapped_column(String(16), nullable=False)
    # pending | verified | expired
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="pending")
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    last_checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_result: Mapped[str | None] = mapped_column(String(32), nullable=True)
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    tiktok_user_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
