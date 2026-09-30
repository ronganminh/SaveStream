from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from .models import Base


class PricingRule(Base):
    __tablename__ = "pricing_rules"
    __table_args__ = (
        UniqueConstraint("version", name="uq_pricing_rules_version"),
        Index("ix_pricing_rules_active", "is_active", "effective_from"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version: Mapped[str] = mapped_column(String(80), nullable=False)
    credit_unit: Mapped[str] = mapped_column(String(24), nullable=False, default="credit")
    policy_type: Mapped[str] = mapped_column(String(80), nullable=False)
    policy: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    public_rules: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    effective_from: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class PricingSnapshot(Base):
    __tablename__ = "pricing_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pricing_rule_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("pricing_rules.id", ondelete="RESTRICT"), nullable=False
    )
    version: Mapped[str] = mapped_column(String(80), nullable=False)
    credit_unit: Mapped[str] = mapped_column(String(24), nullable=False)
    policy_type: Mapped[str] = mapped_column(String(80), nullable=False)
    policy: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    public_rules: Mapped[list[dict[str, Any]]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CreditAccount(Base):
    __tablename__ = "credit_accounts"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_credit_accounts_user_id"),
        CheckConstraint("posted_balance >= 0", name="posted_balance_nonnegative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    posted_balance: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class CreditLedgerEntry(Base):
    __tablename__ = "credit_ledger_entries"
    __table_args__ = (
        UniqueConstraint("reference_key", name="uq_credit_ledger_reference_key"),
        Index("ix_credit_ledger_user_created", "user_id", "created_at"),
        CheckConstraint("balance_after >= 0", name="ledger_balance_after_nonnegative"),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("credit_accounts.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    entry_type: Mapped[str] = mapped_column(String(24), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    balance_after: Mapped[int] = mapped_column(Integer, nullable=False)
    reference_type: Mapped[str] = mapped_column(String(80), nullable=False)
    reference_id: Mapped[str | None] = mapped_column(String(160), nullable=True)
    reference_key: Mapped[str] = mapped_column(String(255), nullable=False)
    details: Mapped[dict[str, Any]] = mapped_column("metadata", JSON, nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class CreditReservation(Base):
    __tablename__ = "credit_reservations"
    __table_args__ = (
        UniqueConstraint("recording_id", name="uq_credit_reservations_recording_id"),
        Index("ix_credit_reservations_user_created", "user_id", "created_at"),
        Index("ix_credit_reservations_account_status", "account_id", "status"),
        CheckConstraint("reserved >= 0", name="reservation_reserved_nonnegative"),
        CheckConstraint("settled >= 0", name="reservation_settled_nonnegative"),
        CheckConstraint("released >= 0", name="reservation_released_nonnegative"),
        CheckConstraint(
            "settled + released <= reserved",
            name="reservation_not_overconsumed",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid.uuid4)
    account_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("credit_accounts.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    recording_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("recordings.id", ondelete="CASCADE"), nullable=False
    )
    pricing_snapshot_id: Mapped[uuid.UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("pricing_snapshots.id", ondelete="RESTRICT"),
        nullable=False,
    )
    reserved: Mapped[int] = mapped_column(Integer, nullable=False)
    settled: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    released: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="active")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )
